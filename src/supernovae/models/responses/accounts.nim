type
  AccountCreatedSuccess* = object
    success*: string = "Account Created"
  
  AccountLoginSuccess* = object
    success*: string = "Account Logged In"
    session*: string # Session ID

  UsernameTakenError* = object
    error*: string = "Username Taken"
    msg*: string = "The username is already taken!"

  EmailTakenError* = object
    error*: string = "Email Taken"
    msg*: string = "The email is already taken!"

  InvalidCredentialsError* = object
    error*: string = "Invalid Credentials"
    msg*: string = "The information provided is incorrect or has no meaning!"