# coding: UTF-8

require File.expand_path(File.dirname(__FILE__) + '/../acceptance_helper')

feature "Superadmin's users API" do

  background do
    Capybara.current_driver = :rack_test
    @new_user = new_user(:password => "this_is_a_password")
    @user_atts = @new_user.values
  end

  scenario "Http auth is needed" do
    post_json superadmin_users_path, { :format => "json" } do |response|
      response.status.should == 401
    end
  end

  scenario "user create fail" do
    @user_atts[:email] = nil

    post_json superadmin_users_path, { :user => @user_atts }, default_headers do |response|
      response.status.should == 422
      response.body[:email].should be_present
      response.body[:email].should include("is not present")
    end
  end

  scenario "user create with password success" do
    @user_atts.delete(:crypted_password)
    @user_atts.delete(:salt)
    @user_atts.merge!(:password => "this_is_a_password")

    post_json superadmin_users_path, { :user => @user_atts }, default_headers do |response|
      response.status.should == 201
      response.body[:email].should == @user_atts[:email]
      response.body[:username].should == @user_atts[:username]
      response.body.should_not have_key(:crypted_password)
      response.body.should_not have_key(:salt)

      # Double check that the user has been created properly
      user = User.filter(:email => @user_atts[:email]).first
      user.should be_present
      user.id.should == response.body[:id]
      User.authenticate(user.username, "this_is_a_password").should == user
    end
  end
  
  scenario "user create with crypted_password and salt success" do
    post_json superadmin_users_path, { :user => @user_atts }, default_headers do |response|
      response.status.should == 201
      response.body[:email].should == @user_atts[:email]
      response.body[:username].should == @user_atts[:username]
      response.body.should_not have_key(:crypted_password)
      response.body.should_not have_key(:salt)
      
      # Double check that the user has been created properly
      user = User.filter(:email => @user_atts[:email]).first
      user.should be_present
      user.id.should == response.body[:id]
      User.authenticate(user.username, "this_is_a_password").should == user
    end
  end
  
  scenario "user update fail" do
    user = create_user
    
    put_json superadmin_user_path(user), { :user => { :email => "" } }, default_headers do |response|
      response.status.should == 422
    end
  end
  
  scenario "user update success" do
    user = create_user
    put_json superadmin_user_path(user), { :user => { :email => "newmail@test.com" } }, default_headers do |response|
      response.status.should == 200
    end
    user = User[user.id]
    user.email.should == "newmail@test.com"
  end
  
  scenario "user delete success" do
    user = create_user
    delete_json superadmin_user_path(user), default_headers do |response|
      response.status.should == 200
    end
    User[user.id].should be_nil
  end
  
  private
  
  def default_headers(user = APP_CONFIG[:superadmin]["username"], password = APP_CONFIG[:superadmin]["password"])
    { 
      'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(user, password),
      'HTTP_ACCEPT' => "application/json"
    }
  end
end
