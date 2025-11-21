-- Create storage bucket for message attachments (audio, images, files)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'messages',
  'messages',
  true,
  10485760, -- 10MB limit for message attachments
   ARRAY[
     'audio/m4a', 'audio/mp3', 'audio/wav', 'audio/aac', 'audio/wave',
     'image/jpeg', 'image/png', 'image/webp', 'image/gif',
     'application/pdf', 'text/plain', 'application/msword',
     'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
   ]
) ON CONFLICT (id) DO NOTHING;

-- Create policy for message attachment uploads
CREATE POLICY "Users can upload message attachments" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'messages' AND
    auth.role() = 'authenticated'
  );

-- Create policy for message attachment updates
CREATE POLICY "Users can update their message attachments" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'messages' AND
    auth.role() = 'authenticated'
  );

-- Create policy for public message attachment access
CREATE POLICY "Message attachments are publicly accessible" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'messages'
  );

-- Create policy for message attachment deletion
CREATE POLICY "Users can delete their message attachments" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'messages' AND
    auth.role() = 'authenticated'
  );