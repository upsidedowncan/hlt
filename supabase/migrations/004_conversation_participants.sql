-- Add foreign key relationships and improve conversation queries
ALTER TABLE conversations 
ADD COLUMN participant_ids UUID[] DEFAULT '{}';

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_conversations_participant_ids 
ON conversations USING GIN (participant_ids);