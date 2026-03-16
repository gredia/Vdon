# frozen_string_literal: true

class StatusesSearchService < BaseService
  def call(query, account = nil, options = {})
    MastodonOTELTracer.in_span('StatusesSearchService#call') do |span|
      @query   = query&.strip
      @account = account
      @options = options
      @limit   = options[:limit].to_i
      @offset  = options[:offset].to_i
      convert_deprecated_options!

      span.add_attributes(
        'search.offset' => @offset,
        'search.limit' => @limit,
        'search.backend' => Chewy.enabled? ? 'elasticsearch' : 'database'
      )

      status_search_results.tap do |results|
        span.set_attribute('search.results.count', results.size)
      end
    end
  end

  private

  def status_search_results
    request = parsed_query.request
    
    valid_results = []
    current_es_offset = 0
    required_total = @offset + @limit
    
    # 動的なバッチサイズの計算。少なすぎず多すぎないチャンク（最低40件〜最大400件）ずつESから取得する
    batch_size = [[required_total * 2, 40].max, 400].min
    max_es_fetches = 10 # ESへの無駄な無限アクセスを防ぐ安全装置（最大10回ループ）
    
    max_es_fetches.times do
      results = request.collapse(field: :id).order(id: { order: :desc }).limit(batch_size).offset(current_es_offset).objects.compact
      
      break if results.empty? # ESにもう続きのデータがなければ終了
      
      account_ids         = results.map(&:account_id)
      account_domains     = results.map(&:account_domain)
      preloaded_relations = @account.relations_map(account_ids, account_domains)
      # フィルターで弾かれたものは配列から消える
      filtered_batch = results.reject { |status| StatusFilter.new(status, @account, preloaded_relations).filtered? }
      
      valid_results.concat(filtered_batch)
      
      # フィルター「通過後」の件数が、フロントエンドから要求された合計件数に達したら完了
      break if valid_results.size >= required_total
      
      # 足りなければESのオフセットを進めて次のチャンクを取得しに行く
      current_es_offset += batch_size
    end
    # フロントエンドが既に持っている @offset 分を読み飛ばし、次の @limit 件だけを厳密に返す
    valid_results.drop(@offset).first(@limit)
  rescue Faraday::ConnectionFailed, Parslet::ParseFailed, Errno::ENETUNREACH
    []
  end

  def parsed_query
    SearchQueryTransformer.new.apply(SearchQueryParser.new.parse(@query), current_account: @account)
  end

  def convert_deprecated_options!
    syntax_options = []

    if @options[:account_id]
      username = Account.select(:username, :domain).find(@options[:account_id]).acct
      syntax_options << "from:@#{username}"
    end

    if @options[:min_id]
      timestamp = Mastodon::Snowflake.to_time(@options[:min_id].to_i)
      syntax_options << "after:\"#{timestamp.iso8601}\""
    end

    if @options[:max_id]
      timestamp = Mastodon::Snowflake.to_time(@options[:max_id].to_i)
      syntax_options << "before:\"#{timestamp.iso8601}\""
    end

    @query = "#{@query} #{syntax_options.join(' ')}".strip if syntax_options.any?
  end
end
