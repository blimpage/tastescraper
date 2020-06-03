require "scraperwiki"
require "mechanize"

agent = Mechanize.new

username = "blimpage"
fan_id = 11254
collection_url = "https://bandcamp.com/#{username}"

# Read in a page
page = agent.get(collection_url)

# Find something on the page using css selectors
album_elements = page.search('.collection-item-container')

albums = album_elements.map do |album_element|
  link_element = album_element.search(".item-link").first

  {
    title: album_element.search(".collection-item-title").first.inner_text.gsub("(gift given)", "").strip,
    artist: album_element.search(".collection-item-artist").first.inner_text.strip.gsub(/\Aby /, ""),
    url: agent.agent.resolve(link_element["href"]).to_s,
  }
end

p albums

# From here we need to grab further albums by hitting Bandcamp's JSON API.
# Each request needs a token from the previous request, and we can grab our
# first "last token" out of the DOM here.
last_token = album_elements.last["data-token"]





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
