require "watir"
ie = Watir::IE.new  #create an object to drive the browser
ie.goto "http://www.google.com/"
ie.url == "http://www.google.com/"
ie.link(:text, "Images").flash #flash the item text "Images"
ie.link(:text, "Images").click #click on the link to the images search page
ie.text.include? "The most comprehensive image search on the web" #test to make sure it worked
searchTerm = "kittens" #set a variable to hold our search term
ie.text_field(:name, "q").set(searchTerm) # q is the name of the search field
ie.button(:name, "btnG").click # "btnG" is the name of the google button
if ie.contains_text(searchTerm)
  puts "Test Passed. Found the test string: #{searchTerm}. Actual Results match Expected Results."
else
   puts "Test Failed! Could not find: #{searchTerm}"
end