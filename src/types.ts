export interface Profile {
  id: string
  member_code: string
  display_name: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface Availability {
  id: string
  user_id: string
  day: string
  note: string | null
  place: string | null
  created_at: string
  updated_at: string
}
