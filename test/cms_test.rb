ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require 'yaml'

require 'bcrypt'


require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
  
   def setup
    FileUtils.mkdir_p(data_path)
    reset_user_logins
  end

  def teardown
    FileUtils.rm_rf(data_path)
    post "/users/signout"
  end
  
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end
  
  def get_root_file_path()
    File.expand_path("..", __FILE__)
  end 
  
  def session
    last_request.env["rack.session"]
  end
  
  
  def get_file_names
    file_path = data_path
     files = []
    Dir.new(file_path).each_child { |file| files << file }
    
    files
  end
  
  def admin_session
  { "rack.session" => { username: "leah", password: "password" } }
  end
  
  def reset_user_logins
    hashed_password = BCrypt::Password.create("password")
      file_path = get_root_file_path() + '/users.yml'
      File.open(file_path, 'w') do |file|
      file.write(YAML.dump({"leah" => hashed_password}))
    end 
    
  end
  
  def test_index
    create_document "about.md"
    create_document "changes.txt"
    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"

  end
  
  def test_viewing_text_document
    create_document("history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby.")
    get "/history.txt" 
      assert_equal("text/plain", last_response['Content-Type'])
      assert_equal(200, last_response.status)
      assert_includes(last_response.body, "1993 - Yukihiro Matsumoto dreams up Ruby.")
  end
  
   def test_viewing_markdown_document
    create_document("about.md", "# Headline")
    
    get "/about.md"
    
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response['Content-Type'])
    assert_includes(last_response.body, "<h1>Headline</h1>")
   end

  def test_document_not_found
      get "/no.txt"
    assert_equal(302, last_response.status)  # assert that the user was redirected. 
    
    assert_equal("no.txt does not exist.", session[:message])
  end
  

  def test_editing_document
    create_document("history.txt")
    get "/history.txt/edit", {}, admin_session
    
    assert_equal(200, last_response.status)
    assert_includes last_response.body, "<textarea"
    assert_includes(last_response.body, %q(<button type="submit"))
  end
  
  def test_editing_document_signed_out
    create_document("history.txt")
    
    get "/history.txt/edit"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end
  
  def test_updating_document
    skip
    post "/history.txt", {file_edit_form:  "1993 - Yukihiro Matsumoto dreams up Ruby."}, admin_session
    
    assert_equal(302, last_response.status)
    assert_equal( "history.txt has been updated.", session[:message])

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto dreams up Ruby."
  end
  
  def test_updating_document_signed_out
     create_document("history.txt")
    
    post "/history.txt", {content: "new content"}
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
    
  end
    
    
  def test_view_new_document_form
    get "/new", {}, admin_session
    
    assert_equal(200, last_response.status)
    assert_includes last_response.body, %q(type="text")
    assert_includes last_response.body, %q(<button type="submit")
    
  end
  def test_view_new_document_form_signed_out
    get "/new"
    
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end
    
  def test_creating_document
    post "/create", {filename:  "test.txt"}, admin_session
    assert_equal(302, last_response.status)  # testing does this; status when going from get to post request
    assert_equal("test.txt has been created.", session[:message])

    get "/"
    assert_nil(session[:message])
    assert_includes last_response.body, "test.txt"
  end
  
  def test_creating_document_signed_out
    
    post "/create",  {filename: "test.txt"}
    
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end
  
  def test_create_new_document_without_filename
    post "/create", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end 
  
  def test_create_new_document_with_invalid_file_extension
    post "/create", {filename: "no"}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "File type not accepted; Please add a valid file extension"
  end

  def test_duplicate_document
    create_document("hi.txt", "content")
    post "/hi.txt/duplicate", {}, admin_session
    get "/"
    assert_includes last_response.body, "hi_copy.txt"
  end
  
  def test_delete_document
    create_document("hi.txt", "content")
    post  '/hi.txt/delete', {},admin_session

    assert_equal(302, last_response.status)  # testing does this; status when going from get to post request
    assert_equal("hi.txt has been deleted.", session[:message])

     get "/"
    refute_includes last_response.body, %q(href="/hi.txt")
  end
  
  def test_delete_document_signed_out
     create_document("hi.txt", "content")
     post "/hi.txt/delete",  {filename: "test.txt"}
    
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end
  
  
  def test_signin_form
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "leah", password: "password"
    assert_equal 302, last_response.status
    assert_equal("Welcome!", session[:message])
    assert_equal "leah", session[:username]
    
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as leah"
  end
  
  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end
  
  def test_signin_with_correct_username_bad_password
    post "/users/signin", username: "leah", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end
  
  def test_signout
    get "/", {}, admin_session
     assert_includes last_response.body, "Signed in as leah"

    post "/users/signout"
    assert_equal "You have been signed out", session[:message]
    assert_nil session[:username]
    get "/users/signin"
    assert_includes last_response.body, "Sign in"
  end
  
  def test_signup_and_signin
    post "/users/signup", {username: "Oscar101", password: "goodpassword101"}, {}
    p  last_response.body
    assert_equal "Sign Up Successful. Time to login!", session[:message] 
    
    post "/users/signin", {username: "Oscar101", password: "goodpassword101"}, {}
    assert_includes last_response.body, "Welcome!"
    #assert_equal("Welcome!", session[:message])
    assert_equal "Oscar101", session[:username]
  end 
  
  def test_signup_preexisting_username
    post "/users/signup", {username: "leah", password: "goodpassword101"} , {}
    assert_equal 422, last_response.status
    assert_includes last_response.body,  "Username is already taken."
    # assert_equal "Username is already taken.", session[:message] 
  end 
  
  def test_viewing_image
    get '/'
    assert_includes(last_response.body, "Leah_Garrison.jpg")
    
    # get '/:Leah_Garrison.jpg' 
    # assert_includes last_response.body, "![image]"
    
  end 
    
    
  # def test_view_previous_file_version
    
  # end
  
  # def test_view_current_file_version
    
  # end
  
  # def test_add_new_file_version
    
  # end
  
end