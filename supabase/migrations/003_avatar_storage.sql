-- Create storage bucket for avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152, -- 2MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create policy for avatar uploads
CREATE POLICY "Users can upload their own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated' AND 
    SPLIT_PART(name, '/', 1) = auth.uid()::text
  );

-- Create policy for avatar updates
CREATE POLICY "Users can update their own avatar" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated' AND 
    SPLIT_PART(name, '/', 1) = auth.uid()::text
  );

-- Create policy for public avatar access
CREATE POLICY "Avatars are publicly accessible" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'avatars'
  );