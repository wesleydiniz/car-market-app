class UsersService

  def find(user_id)
    User.cache do
      return User.find(user_id)
      end
  end
end