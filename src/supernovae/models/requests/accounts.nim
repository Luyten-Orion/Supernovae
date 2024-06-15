type
  AccountRegistrationRequest* = object
    username*, email*, password*: string
  
  AccountLoginRequest* = object
    email*, password*: string