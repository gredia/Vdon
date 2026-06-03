import PropTypes from 'prop-types';
import { useCallback, useEffect, useRef } from 'react';

import { defineMessages, FormattedMessage, useIntl } from 'react-intl';

import { Helmet } from 'react-helmet';
import { NavLink } from 'react-router-dom';

import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import { connectVirtualKemomimiRelayStream } from 'mastodon/actions/streaming';
import { expandVirtualKemomimiRelayTimeline } from 'mastodon/actions/timelines';
import { DismissableBanner } from 'mastodon/components/dismissable_banner';
import { useIdentity } from 'mastodon/identity_context';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import Column from '../../components/column';
import ColumnHeader from '../../components/column_header';
import StatusListContainer from '../ui/containers/status_list_container';

const messages = defineMessages({
  title: { id: 'column.virtual_kemomimi_relay', defaultMessage: 'ぶいみみリレー' },
});

const VirtualKemomimiRelayTimeline = ({ social, multiColumn }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();
  const { signedIn } = useIdentity();
  const columnRef = useRef(null);
  const timelineId = social ? 'virtual_kemomimi_relay:social' : 'virtual_kemomimi_relay';
  const hasUnread = useAppSelector((state) => state.getIn(['timelines', timelineId, 'unread'], 0) > 0);

  const handleLoadMore = useCallback(
    (maxId) => {
      dispatch(expandVirtualKemomimiRelayTimeline({ maxId, social }));
    },
    [dispatch, social],
  );

  const handleHeaderClick = useCallback(() => columnRef.current?.scrollTop(), []);

  useEffect(() => {
    dispatch(expandVirtualKemomimiRelayTimeline({ social }));

    let disconnect;

    if (signedIn) {
      disconnect = dispatch(connectVirtualKemomimiRelayStream({ social }));
    }

    return () => disconnect?.();
  }, [dispatch, signedIn, social]);

  const prependBanner = social ? (
    <DismissableBanner id='virtual_kemomimi_relay_social_timeline'><FormattedMessage id='dismissable_banner.virtual_kemomimi_relay_social' defaultMessage='バーチャルけもみみリレー参加サーバーの公開投稿、あなたの公開投稿、自分がフォローしているアカウントの公開投稿を表示します。' /></DismissableBanner>
  ) : (
    <DismissableBanner id='virtual_kemomimi_relay_timeline'><FormattedMessage id='dismissable_banner.virtual_kemomimi_relay' defaultMessage='バーチャルけもみみリレー参加サーバーの公開投稿と、あなたの公開投稿を表示します。' /></DismissableBanner>
  );

  return (
    <Column bindToDocument={!multiColumn} ref={columnRef} label={intl.formatMessage(messages.title)}>
      <ColumnHeader
        icon='globe'
        iconComponent={PublicIcon}
        active={hasUnread}
        title={intl.formatMessage(messages.title)}
        onClick={handleHeaderClick}
        multiColumn={multiColumn}
      />

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
        trackScroll
        scrollKey={`virtual_kemomimi_relay-${social ? 'social' : 'timeline'}`}
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
  multiColumn: PropTypes.bool,
  social: PropTypes.bool,
};

export default VirtualKemomimiRelayTimeline;
