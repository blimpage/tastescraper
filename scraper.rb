require "scraperwiki"
require "mechanize"

agent = Mechanize.new

username = "blimpage"
collection_url = "https://bandcamp.com/#{username}"

# Read in a page
page = agent.get(collection_url)

# Find something on the page using css selectors
album_elements = page.search('.collection-title-details')

albums = album_elements.map do |album|
  link_element = album.children.detect { |el| el["class"] == "item-link" }

  {
    title: link_element.children.detect { |el| el["class"] == "collection-item-title" }.inner_text.gsub("(gift given)", "").strip,
    artist: link_element.children.detect { |el| el["class"] == "collection-item-artist" }.inner_text.strip.gsub(/\Aby /, ""),
    url: agent.agent.resolve(link_element["href"]).to_s,
  }
end

p albums

# Button that loads more albums.
# Once this is clicked, it loads more albums, then waits until the user has
# scrolled down to the bottom of the page to load more.
page.at(".show-more")

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
