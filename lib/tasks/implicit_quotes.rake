# frozen_string_literal: true

namespace :mastodon do
  namespace :maintenance do
    desc 'Backfill pending quotes that are implicitly allowed'
    task backfill_implicit_quotes: :environment do
      apply = ActiveModel::Type::Boolean.new.cast(ENV.fetch('APPLY', false))
      count = ActivityPub::AcceptImplicitQuoteWorker.enqueue_pending(dry_run: !apply)

      if apply
        puts "Enqueued #{count} implicit quote(s) for acceptance."
      else
        puts "Found #{count} implicit quote(s) requiring acceptance."
        puts 'Run again with APPLY=true to enqueue the backfill.'
      end
    end
  end
end
