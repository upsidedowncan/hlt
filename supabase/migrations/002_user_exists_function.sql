-- Edge Function: user_exists
-- This function checks if a user exists in the auth system
CREATE OR REPLACE FUNCTION user_exists(email_input TEXT)
RETURNS JSON AS $$
DECLARE
  user_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count
  FROM auth.users
  WHERE email = email_input;
  
  RETURN json_build_object('exists', user_count > 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;