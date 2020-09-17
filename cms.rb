require 'sinatra'
require "sinatra/reloader"
require 'erubis'
require 'tilt/erubis'
require 'redcarpet'

require 'yaml'

require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

configure do
  set :erb, :escape_html => true
end

# configure do 
#   file = File.open(get_root_file_path() + '/valid_logins.yml')
#   @valid_users = YAML::load(file)
# end

  # markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  # markdown.render("# This will be a headline!")
helpers do 
  def render_markdown(markdown_text)   # takes markdown formatted text and return its output formatted as HTML
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(markdown_text)
  end
  
  def user_signed_in?()
    credentials = load_user_credentials
    true if credentials.keys.include?(session[:username])
  end 
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

get '/' do
  if user_signed_in?
    @files = get_file_names(data_path)
    erb :index, layout: :layout
  else redirect '/users/signin'
  end
end

get '/users/signin' do 
  erb :signin
end

def handle_invalid_user_login
   session[:message] = "Invalid Credentials"
    status 422
    erb :signin
end

post '/users/signin' do
  credentials = load_user_credentials
  username = params[:username].to_s
  if !credentials.key?(username)
    handle_invalid_user_login
  elsif  credentials.key?(username) 
    bycrypt_password = BCrypt::Password.new(credentials[username])  # unhashes the saved hash password  #(hash_password, user_input)
    return handle_invalid_user_login if bycrypt_password != params[:password]
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  end
end

post '/users/signout' do 
  session.delete(:username)
  session.delete(:password)
  session[:message] = "You have been signed out"
  redirect "/"
end

get '/new' do 
  require_signed_in_user
  erb :new_document
end

post '/create' do 
  require_signed_in_user
  new_doc_name = params[:filename].to_s.strip
  error = error_for_doc_name(new_doc_name)
  if error
    session[:message] = error
    status 422
    erb :new_document
  else 
    file_path = File.join(data_path, new_doc_name)
    File.write(file_path, "")
    session[:message] = "#{new_doc_name} has been created."
    redirect '/'
  end
end

get '/:file_name' do |file_name|
  basename = File.basename(file_name)
  file_path = File.join(data_path, basename)
  if File.exist?(file_path)
    headers \
    "Content-Type" => get_header_content_type(file_name)
    process_file_content(file_path, file_name)
  else
    session[:message] = "#{file_name} does not exist."
    redirect "/"
  end 
end

get '/:file_name/edit' do |file_name|
  require_signed_in_user
  file_path = File.join(data_path, file_name)
  @file_content = File.read(file_path)#  process_file_content(file_path)
  erb :edit_file, layout: :layout
end

post '/:file_name' do |file_name|
  require_signed_in_user
  
  create_new_version(file_name, params[:file_edit_form])

 
  # file_path = File.join(data_path, file_name)
  # File.write(file_path, params[:file_edit_form])
  session[:message] = "#{file_name} has been updated."

  redirect "/"
end


# def create_past_versions_directory(file_name)
  
# end
def create_new_version(file_name, updated_data)
    directory_path = past_version_path(file_name)
  if !Dir.exist?(directory_path)
    Dir.mkdir(directory_path)
  end
  version = (get_file_names(directory_path).size + 1).to_s
  
    new_path = directory_path + "/" + get_updated_name(file_name, version)
    current_path = data_path + "/" + file_name
    File.write(new_path, "" )
    FileUtils.mv(current_path, new_path)
    File.write(current_path, updated_data)
  
end

post '/:file_name/delete' do |file_name|
  require_signed_in_user
  file_path = File.join(data_path, file_name)
  File.delete(file_path)
  if !File.exist?(file_path)
    session[:message] = "#{file_name} has been deleted."
    redirect '/'
  end
end
  
post '/:filename/duplicate' do |file_name|
  duplicate_document(file_name)
  redirect '/'
end

get '/users/signup' do
  erb :signup
end

post '/users/signup' do 
  error = error_for_username_signup(params[:username])
  if error
    session[:message] = error
    status 422
    erb :signup
  else 
    #load_user_credentials
    file_path = get_root_file_path() + '/users.yml'
    hashed_password = hide_password(params[:password])
    data = YAML.load_file(file_path)
    data[params[:username]] = hashed_password
    File.open(file_path, 'w') do |file|
      file.write(YAML.dump(data))
    end 
    session[:message] = "Sign Up Successful. Time to login!"
    redirect "/users/signin"
  end 
 end
 
 get '/:file_name/past_versions' do
    
   @files = get_file_names(past_version_path(params[:file_name]))
  erb :past_versions
end 
 
 def past_version_path(file_name)
   basename = File.basename(file_name, ".*") 
  data_path + "/" + basename + "_past_versions"
  end
  
 def hide_password(password)
    BCrypt::Password.create(password)  # hashes the plain-text password
 end

 
    
def error_for_username_signup(username)
    @users = load_user_credentials
  if username.length == 0
   "A username is required."
  elsif @users.keys.include?(username)
    session[:message] = "Username is already taken."
  end 
end 


def accepted_file_formats
   [".txt", ".md", ".png", ".jpg", ".jpeg"]
end

def get_file_names(path)
  Dir.glob(path + "/*.{txt,md,png,jpg,jpeg}").map do |path|
      File.basename(path)
  end
end


def get_root_file_path()
  File.expand_path("..", __FILE__)
end 

def get_header_content_type(file_path)
  file_extension = File.extname(file_path)
  if file_extension == ".txt"
    "text/plain"
  elsif [".md",".jpg", ".jpeg", ".png"].include?(file_extension)
    "text/html;charset=utf-8"
  end
end

# LS method
# def load_file_content(path)
#   content = File.read(path)
#   case File.extname(path)
#   when ".txt"
#     headers["Content-Type"] = "text/plain"
#     content
#   when ".md"
#     render_markdown(content)
#   end
# end

def process_file_content(file_path, file_name)
  file_extension = File.extname(file_path)
  if file_extension == ".txt"
    IO.read(file_path)
  elsif file_extension == ".md"
    text = IO.read(file_path)
    erb render_markdown(text)
  elsif [".png", ".jpg", ".jpeg"].include?(file_extension)
    process_image(file_path, file_name)
     text = IO.read(file_path)
    erb render_markdown(text)
  end
end

def process_image(file_path, file_link)
  #name = "/data/" + file_name
  markdown_text = "![image](#{file_path})"
  File.write(file_path, markdown_text)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def error_for_doc_name(name)
  formats = accepted_file_formats()
  extension = File.extname(name)
  # if list_name.size >= 1 && list_name.size <= 100
  if name.length == 0
    "A name is required."
  elsif !formats.include?(extension)
    "File type not accepted; Please add a valid file extension."
  elsif get_file_names(data_path).any? { |file_name| file_name == name }
    'File name must be unique.'
  end
end


def require_signed_in_user
  unless user_signed_in?()
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def duplicate_document(file_name)
    file_path = File.join(data_path, file_name)
    # file_extension = File.extname(file_name)
    # basename = File.basename(file_path, ".*") 
    # copied_file_name = basename + "_copy" + file_extension
    # copied_file_path = File.join(data_path, copied_file_name)
    copied_file_name = get_updated_name(file_name, "_copy")
    copied_file_path = File.join(data_path, copied_file_name)
    File.write(copied_file_path, File.read(file_path))
    session[:message] = "A copy of #{file_name} has been created. The new document is called #{copied_file_name}. "
end


def get_updated_name(file_name, end_file_string)
    # file_path = File.join(data_path, file_name)
    file_extension = File.extname(file_name)
    basename = File.basename(file_name, ".*") 
    basename + end_file_string + file_extension
end
