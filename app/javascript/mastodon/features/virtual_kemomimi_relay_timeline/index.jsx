import PropTypes from 'prop-types';
import { useCallback, useEffect, useRef } from 'react';

import { defineMessages, FormattedMessage, useIntl } from 'react-intl';

import { Helmet } from '@unhead/react/helmet';
import { NavLink } from 'react-router-dom';

import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { changeSetting } from 'mastodon/actions/settings';
import { connectVirtualKemomimiRelayStream } from 'mastodon/actions/streaming';
import { expandVirtualKemomimiRelayTimeline } from 'mastodon/actions/timelines';
import { DismissableBanner } from 'mastodon/components/dismissable_banner';
import { me } from 'mastodon/initial_state';
import { useIdentity } from 'mastodon/identity_context';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import Column from '../../components/column';
import ColumnHeader from '../../components/column_header';
import SettingToggle from '../notifications/components/setting_toggle';
import StatusListContainer from '../ui/containers/status_list_container';

const messages = defineMessages({
  title: { id: 'column.virtual_kemomimi_relay', defaultMessage: 'ぶいみみリレー' },
});

const ColumnSettings = () => {
  const dispatch = useAppDispatch();
  const settings = useAppSelector((state) => state.getIn(['settings', 'virtual_kemomimi_relay']));
  const onChange = useCallback(
    (key, checked) => dispatch(changeSetting(['virtual_kemomimi_relay', ...key], checked)),
    [dispatch],
  );

  return (
    <div className='column-settings'>
      <section>
        <div className='column-settings__row'>
          <SettingToggle
            prefix='virtual_kemomimi_relay'
            settings={settings}
            settingPath={['shows', 'reblog']}
            onChange={onChange}
            label={<FormattedMessage id='home.column_settings.show_reblogs' defaultMessage='Show boosts' />}
          />

          <SettingToggle
            prefix='virtual_kemomimi_relay'
            settings={settings}
            settingPath={['shows', 'quote']}
            onChange={onChange}
            label={<FormattedMessage id='home.column_settings.show_quotes' defaultMessage='Show quotes' />}
          />

          <SettingToggle
            prefix='virtual_kemomimi_relay'
            settings={settings}
            settingPath={['shows', 'reply']}
            onChange={onChange}
            label={<FormattedMessage id='home.column_settings.show_replies' defaultMessage='Show replies' />}
          />

          <SettingToggle
            prefix='virtual_kemomimi_relay'
            settings={settings}
            settingPath={['onlyMedia']}
            onChange={onChange}
            label={<FormattedMessage id='community.column_settings.media_only' defaultMessage='Media only' />}
          />
        </div>
      </section>
    </div>
  );
};

const VirtualKemomimiRelayTimeline = ({ social, columnId, multiColumn }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();
  const { signedIn } = useIdentity();
  const columnRef = useRef(null);
  const pinned = !!columnId;
  const settings = useAppSelector((state) => state.getIn(['settings', 'virtual_kemomimi_relay']));
  const onlyMedia = settings.get('onlyMedia', false);
  const showReblogs = settings.getIn(['shows', 'reblog'], true);
  const showReplies = settings.getIn(['shows', 'reply'], true);
  const showQuotes = settings.getIn(['shows', 'quote'], true);
  const timelineId = `virtual_kemomimi_relay${social ? ':social' : ''}${onlyMedia ? ':media' : ''}`;
  const hasUnread = useAppSelector((state) => state.getIn(['timelines', timelineId, 'unread'], 0) > 0);

  const timelineOptions = {
    social,
    onlyMedia,
    showReblogs,
    showReplies,
    showQuotes,
  };

  const acceptStatus = useCallback((status) => {
    if (status.account?.id === me) {
      return true;
    }

    if (onlyMedia && status.media_attachments?.length === 0) {
      return false;
    }

    if (!showReblogs && status.reblog != null) {
      return false;
    }

    if (!showReplies && status.in_reply_to_id != null && status.in_reply_to_account_id !== me) {
      return false;
    }

    if (!showQuotes && status.quote != null) {
      return false;
    }

    return true;
  }, [onlyMedia, showReblogs, showReplies, showQuotes]);

  const handlePin = useCallback(() => {
    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('VIRTUAL_KEMOMIMI_RELAY', { other: { social } }));
    }
  }, [columnId, dispatch, social]);

  const handleMove = useCallback((dir) => {
    dispatch(moveColumn(columnId, dir));
  }, [columnId, dispatch]);

  const handleLoadMore = useCallback(
    (maxId) => {
      dispatch(expandVirtualKemomimiRelayTimeline({ ...timelineOptions, maxId }));
    },
    [dispatch, social, onlyMedia, showReblogs, showReplies, showQuotes],
  );

  const handleHeaderClick = useCallback(() => columnRef.current?.scrollTop(), []);

  useEffect(() => {
    dispatch(expandVirtualKemomimiRelayTimeline(timelineOptions));

    let disconnect;

    if (signedIn) {
      disconnect = dispatch(connectVirtualKemomimiRelayStream({ ...timelineOptions, accept: acceptStatus }));
    }

    return () => disconnect?.();
  }, [dispatch, signedIn, social, onlyMedia, showReblogs, showReplies, showQuotes, acceptStatus]);

  const prependBanner = social ? (
    <DismissableBanner id='virtual_kemomimi_relay_social_timeline'><FormattedMessage id='dismissable_banner.virtual_kemomimi_relay_social' defaultMessage='自分のサーバーとバーチャルけもみみリレー参加サーバーの公開投稿、あなたの公開投稿、自分がフォローしているアカウントの公開投稿を表示します。' /></DismissableBanner>
  ) : (
    <DismissableBanner id='virtual_kemomimi_relay_timeline'><FormattedMessage id='dismissable_banner.virtual_kemomimi_relay' defaultMessage='自分のサーバーとバーチャルけもみみリレー参加サーバーの公開投稿、あなたの公開投稿を表示します。' /></DismissableBanner>
  );

  return (
    <Column bindToDocument={!multiColumn} ref={columnRef} label={intl.formatMessage(messages.title)}>
      <ColumnHeader
        icon='globe'
        iconComponent={PublicIcon}
        active={hasUnread}
        title={intl.formatMessage(messages.title)}
        onPin={handlePin}
        onMove={handleMove}
        onClick={handleHeaderClick}
        pinned={pinned}
        multiColumn={multiColumn}
      >
        <ColumnSettings />
      </ColumnHeader>

      <div className='account__section-headline'>
        <NavLink exact to='/virtual-kemomimi-relay'>
          <FormattedMessage tagName='div' id='virtual_kemomimi_relay.timeline' defaultMessage='ぶいみみTL' />
        </NavLink>

        <NavLink exact to='/virtual-kemomimi-relay/social'>
          <FormattedMessage tagName='div' id='virtual_kemomimi_relay.social' defaultMessage='ぶいみみソーシャル' />
        </NavLink>
      </div>

      <StatusListContainer
        prepend={prependBanner}
        timelineId={timelineId}
        onLoadMore={handleLoadMore}
        trackScroll={!pinned}
        scrollKey={`virtual_kemomimi_relay-${social ? 'social' : 'timeline'}-${columnId}`}
        emptyMessage={<FormattedMessage id='empty_column.virtual_kemomimi_relay' defaultMessage='表示できる公開投稿がまだありません。' />}
        bindToDocument={!multiColumn}
      />

      <Helmet>
        <title>{intl.formatMessage(messages.title)}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

VirtualKemomimiRelayTimeline.propTypes = {
  columnId: PropTypes.string,
  multiColumn: PropTypes.bool,
  social: PropTypes.bool,
};

export default VirtualKemomimiRelayTimeline;
