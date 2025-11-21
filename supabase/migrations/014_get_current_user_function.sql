-- Create secure function to get current user profile

CREATE OR REPLACE FUNCTION get_current_user()
RETURNS TABLE (
  id UUID,
  email TEXT,
  username TEXT,
  display_name TEXT,
  avatar_url TEXT,
  is_online BOOLEAN,
  last_seen TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id,
    u.email,
    u.username,
    u.display_name,
    u.avatar_url,
    u.is_online,
    u.last_seen,
    u.created_at,
    u.updated_at
  FROM public.users u
  WHERE u.id = auth.uid()
  LIMIT 1;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_current_user() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_current_user() IS 'Securely get the current authenticated user profile';