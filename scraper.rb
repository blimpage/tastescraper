require "scraperwiki"
require "mechanize"
require "faraday"
require_relative "saved_data"

$agent = Mechanize.new

$username = "blimpage"
$fan_id = 11254

def all_albums_for_collector(username:, fan_id:)
  puts "finding albums for collector #{username} (fan_id #{fan_id})"
  albums_for_collector = []

  collector_page_url = "https://bandcamp.com/#{username}"

  page = $agent.get(collector_page_url)

  puts "grabbing initial albums"

  album_elements = page.search('.collection-item-container')

  initial_albums = album_elements.map do |album_element|
    link_element = album_element.search(".item-link").first

    {
      tralbum_id: album_element["data-tralbumid"].to_i,
      tralbum_type: album_element["data-tralbumtype"],
      title: album_element.search(".collection-item-title").first.inner_text.gsub("(gift given)", "").strip,
      artist: album_element.search(".collection-item-artist").first.inner_text.strip.gsub(/\Aby /, ""),
      url: $agent.agent.resolve(link_element["href"]).to_s,
      collector_ids: [fan_id],
    }
  end

  albums_for_collector += initial_albums

  # From here we need to grab further albums by hitting Bandcamp's JSON API.
  # Each request needs a token from the previous request, and we can grab our
  # first "last token" out of the DOM here.
  last_token = album_elements.last["data-token"]

  more_albums_available = true

  while more_albums_available do
    puts "grabbing more albums via JSON API"

    response = Faraday.post(
      "https://bandcamp.com/api/fancollection/1/collection_items",
      { fan_id: fan_id, older_than_token: last_token, count: 100}.to_json,
      "Content-Type" => "application/json"
    )

    parsed_response = JSON.parse(response.body)

    next_albums = parsed_response["items"].map do |item|
      {
        tralbum_id: item["tralbum_id"].to_i,
        tralbum_type: item["tralbum_type"],
        title: item["item_title"],
        artist: item["band_name"],
        url: item["item_url"],
        collector_ids: [fan_id],
      }
    end

    albums_for_collector += next_albums
    more_albums_available = parsed_response["more_available"]
    last_token = parsed_response["last_token"]
  end

  puts "no more albums, all done!"

  albums_for_collector
end

if $saved_all_albums
  $all_albums = $saved_all_albums
  $my_albums = $saved_my_albums
  puts "Got saved data, skipping getting new data"
else
  $all_albums = {}
  $my_albums = []

  my_albums = all_albums_for_collector(username: $username, fan_id: $fan_id)
  my_albums.each do |album|
    if $all_albums[album[:tralbum_id]]
      $all_albums[album[:tralbum_id]][:collector_ids] += $fan_id
    else
      $all_albums[album[:tralbum_id]] = album
    end
  end
  $my_albums += my_albums.map { |album| album[:tralbum_id] }
end

puts "#{$all_albums.count} albums total."

if $saved_collectors
  $all_collectors = $saved_collectors
else
  $all_collectors = {}

  def get_collectors(tralbum_id:, tralbum_type:)
    puts "getting initial collectors for album #{tralbum_id}."
    collector_count_for_album = 0

    initial_response = Faraday.post(
      "https://bandcamp.com/api/tralbumcollectors/2/initial",
      { tralbum_type: tralbum_type, tralbum_id: tralbum_id, reviews_count: 0, thumbs_count: 500, exclude_fan_ids: [$fan_id] }.to_json,
      "Content-Type" => "application/json"
    )

    parsed_initial_response = JSON.parse(initial_response.body)

    parsed_initial_response["thumbs"].each do |collector|
      collector_count_for_album += 1

      if $all_collectors[collector["fan_id"]]
        $all_collectors[collector["fan_id"]][:tralbum_ids] += [tralbum_id]
      else
        $all_collectors[collector["fan_id"]] = {
          fan_id: collector["fan_id"],
          tralbum_ids: [tralbum_id],
          name: collector["name"],
          username: collector["username"],
          url: collector["url"],
        }
      end
    end

    more_collectors_available = parsed_initial_response["more_thumbs_available"]
    last_token = (parsed_initial_response["thumbs"].last || {}) ["token"]

    while more_collectors_available do
      puts "getting more collectors for album #{tralbum_id}."
      response = Faraday.post(
        "https://bandcamp.com/api/tralbumcollectors/2/thumbs",
        { tralbum_type: tralbum_type, tralbum_id: tralbum_id, token: last_token, count: 500 }.to_json,
        "Content-Type" => "application/json"
      )

      parsed_response = JSON.parse(response.body)

      parsed_response["results"].each do |collector|
        collector_count_for_album += 1

        if $all_collectors[collector["fan_id"]]
          $all_collectors[collector["fan_id"]][:tralbum_ids] += [tralbum_id]
        else
          $all_collectors[collector["fan_id"]] = {
            fan_id: collector["fan_id"],
            tralbum_ids: [tralbum_id],
            name: collector["name"],
            username: collector["username"],
            url: collector["url"],
          }
        end
      end

      more_collectors_available = parsed_response["more_available"]
      last_token = parsed_response["results"].last["token"]
    end

    puts "#{collector_count_for_album} collectors found for album #{tralbum_id}. Now at #{$all_collectors.keys.count} total collectors."
  end

  my_albums_with_full_details = $my_albums.map do |tralbum_id|
    $all_albums.detect do |album|
      album[:tralbum_id] == tralbum_id
    end
  end

  my_albums_with_full_details.each do |album|
    get_collectors(tralbum_id: album[:tralbum_id], tralbum_type: album[:tralbum_type])
  end
end

collectors_with_more_than_one_album = $all_collectors.values.select do |collector|
  collector[:tralbum_ids].length > 1
end

puts "collectors with more than one album: #{collectors_with_more_than_one_album.count}"

collectors_by_compatibility = $all_collectors
                                .values
                                .group_by { |collector| collector[:tralbum_ids].count }
                                .sort_by { |shared_album_count, _collectors| shared_album_count }

puts "collector count by compatibility:"
puts collectors_by_compatibility.map { |shared_album_count, collectors| [shared_album_count, collectors.count] }.map { |arr| arr.join(": ")}.join(" | ")

puts "most compatible collectors:"
puts collectors_by_compatibility.last

collectors_to_crawl = collectors_by_compatibility
                        .select { |shared_album_count, _collectors| shared_album_count >= 23 }
                        .flat_map { |_shared_album_count, collectors| collectors }

puts "collectors_to_crawl:"
puts collectors_to_crawl.map { |collector| collector[:username] }

