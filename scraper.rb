require "scraperwiki"
require "mechanize"
require "faraday"

agent = Mechanize.new

username = "blimpage"
fan_id = 11254
collection_url = "https://bandcamp.com/#{username}"

all_albums = []

# Read in a page
page = agent.get(collection_url)

puts "grabbing initial albums"

# Find something on the page using css selectors
album_elements = page.search('.collection-item-container')

initial_albums = album_elements.map do |album_element|
  link_element = album_element.search(".item-link").first

  {
    tralbum_id: album_element["data-tralbumid"],
    title: album_element.search(".collection-item-title").first.inner_text.gsub("(gift given)", "").strip,
    artist: album_element.search(".collection-item-artist").first.inner_text.strip.gsub(/\Aby /, ""),
    url: agent.agent.resolve(link_element["href"]).to_s,
  }
end

all_albums += initial_albums

# From here we need to grab further albums by hitting Bandcamp's JSON API.
# Each request needs a token from the previous request, and we can grab our
# first "last token" out of the DOM here.
last_token = album_elements.last["data-token"]

more_albums_available = true

while more_albums_available do
  puts "grabbing more albums via JSON API"

  response = Faraday.post(
    "https://bandcamp.com/api/fancollection/1/collection_items",
    { fan_id: fan_id, older_than_token: last_token, count: 20}.to_json,
    "Content-Type" => "application/json"
  )

  parsed_response = JSON.parse(response.body)

  next_albums = parsed_response["items"].map do |item|
    {
      tralbum_id: item["tralbum_id"],
      title: item["item_title"],
      artist: item["band_name"],
      url: item["item_url"],
    }
  end

  all_albums += next_albums
  more_albums_available = parsed_response["more_available"]
  last_token = parsed_response["last_token"]
end

puts "no more albums, all done!"

puts all_albums

puts "#{all_albums.count} albums total."

# # Write out to the sqlite database using scraperwiki library
# ScraperWiki.save_sqlite(["name"], {"name" => "susan", "occupation" => "software developer"})
#
# # An arbitrary query against the database
# ScraperWiki.select("* from data where 'name'='peter'")

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".
