# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FanOutOnWriteService do
  subject { described_class.new }

  let(:last_active_at) { Time.now.utc }
  let(:status) { Fabricate(:status, account: alice, visibility: visibility, text: 'Hello @bob @eve #hoge') }

  let!(:alice) { Fabricate(:user, current_sign_in_at: last_active_at).account }
  let!(:bob)   { Fabricate(:user, current_sign_in_at: last_active_at, account_attributes: { username: 'bob' }).account }
  let!(:tom)   { Fabricate(:user, current_sign_in_at: last_active_at).account }
  let!(:eve)   { Fabricate(:user, current_sign_in_at: last_active_at, account_attributes: { username: 'eve' }).account }

  before do
    bob.follow!(alice)
    tom.follow!(alice)

    ProcessMentionsService.new.call(status)
    ProcessHashtagsService.new.call(status)

    Fabricate(:media_attachment, status: status, account: alice)

    allow(redis).to receive(:publish)

    subject.call(status)
  end

  def home_feed_of(account)
    HomeFeed.new(account).get(10).map(&:id)
  end

  context 'when status is public' do
    let(:visibility) { 'public' }

    it 'adds status to home feed of author and followers and broadcasts', :inline_jobs do
      expect(status.id)
        .to be_in(home_feed_of(alice))
        .and be_in(home_feed_of(bob))
        .and be_in(home_feed_of(tom))

      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      expect(redis).to have_received(:publish).with('timeline:public', anything)
      expect(redis).to have_received(:publish).with('timeline:public:local', anything)
      expect(redis).to have_received(:publish).with('timeline:public:media', anything)
    end

    context 'when status quotes a local account' do
      let(:quoted_status) { Fabricate(:status, account: bob, visibility: :public) }
      let(:status) do
        Fabricate(:status, account: alice, visibility: visibility, text: 'Hello').tap do |status|
          Fabricate(:quote, status: status, quoted_status: quoted_status, state: :accepted)
        end
      end

      it 'notifies the quoted account' do
        expect(LocalNotificationWorker)
          .to have_enqueued_sidekiq_job(bob.id, status.quote.id, 'Quote', 'quote')
      end

      it 'does not notify other local accounts about the quote' do
        expect(LocalNotificationWorker)
          .to_not have_enqueued_sidekiq_job(alice.id, status.quote.id, 'Quote', 'quote')
        expect(LocalNotificationWorker)
          .to_not have_enqueued_sidekiq_job(tom.id, status.quote.id, 'Quote', 'quote')
        expect(LocalNotificationWorker)
          .to_not have_enqueued_sidekiq_job(eve.id, status.quote.id, 'Quote', 'quote')
      end
    end
  end

  context 'when status is limited' do
    let(:visibility) { 'limited' }

    it 'adds status to home feed of author and mentioned followers and does not broadcast', :inline_jobs do
      expect(status.id)
        .to be_in(home_feed_of(alice))
        .and be_in(home_feed_of(bob))
      expect(status.id)
        .to_not be_in(home_feed_of(tom))

      expect_no_broadcasting
    end
  end

  context 'when status is private' do
    let(:visibility) { 'private' }

    it 'adds status to home feed of author and followers and does not broadcast', :inline_jobs do
      expect(status.id)
        .to be_in(home_feed_of(alice))
        .and be_in(home_feed_of(bob))
        .and be_in(home_feed_of(tom))

      expect_no_broadcasting
    end
  end

  context 'when status is direct' do
    let(:visibility) { 'direct' }

    it 'is added to the home feed of its author and mentioned followers and does not broadcast', :inline_jobs do
      expect(status.id)
        .to be_in(home_feed_of(alice))
        .and be_in(home_feed_of(bob))
      expect(status.id)
        .to_not be_in(home_feed_of(tom))

      expect_no_broadcasting
    end

    context 'when handling status updates' do
      before do
        subject.call(status)

        status.snapshot!(at_time: status.created_at, rate_limit: false)
        status.update!(text: 'Hello @bob @eve #hoge (edited)')
        status.snapshot!(account_id: status.account_id)

        redis.set("subscribed:timeline:#{eve.id}:notifications", '1')
      end

      it 'pushes the update to mentioned users through the notifications streaming channel' do
        subject.call(status, update: true)
        expect(PushUpdateWorker).to have_enqueued_sidekiq_job(anything, status.id, "timeline:#{eve.id}:notifications", { 'update' => true })
      end
    end
  end

  def expect_no_broadcasting
    expect(redis)
      .to_not have_received(:publish)
      .with('timeline:hashtag:hoge', anything)
    expect(redis)
      .to_not have_received(:publish)
      .with('timeline:public', anything)
  end
end
