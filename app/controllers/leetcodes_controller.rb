class LeetcodesController < ApplicationController
  before_action :set_leetcode, only: [:edit, :update, :destroy]

  def new
    @leetcode = Leetcode.new
    if params[:temp_token]
      token = TempToken.find_by_token(params[:temp_token])
      @slack = Slack.find(token.slack_id) if token
    end
  end

  def edit
  end

  def create
    args = params.permit(:email, :password, :temp_token)
    if args[:temp_token]
      token = TempToken.find_by_token args[:temp_token]
      if token
        slack = Slack.find token.slack_id
        slack_id = slack.id if slack
      end
    end

    @leetcode = Leetcode.new(
      email: args[:email],
      password: args[:password],
      slack_id: slack_id
    )
    attach_user

    respond_to do |format|
      if @leetcode.save
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: @leetcode }
      else
        format.html { render :new }
        format.json { render json: @leetcode.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @leetcode.update(user_params)
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        format.json { render :show, status: :ok, location: @leetcode }
      else
        format.html { render :edit }
        format.json { render json: @leetcode.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @leetcode.destroy
    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  def set_leetcode
    @leetcode = Leetcode.find(params[:id])
    attach_user
  end

  def attach_user
    @user = User.find_by_email @leetcode.email
    unless @user
      @user = User.new(
        email: @leetcode.email,
        password: @leetcode.password,
        password_confirmation: @leetcode.password
      )
      @user.save
    end
    @slack.update(user_id: @user.id) if (@slack and !@slack.user_id)
  end

end
