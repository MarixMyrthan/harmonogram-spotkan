import { FormEvent, useEffect, useMemo, useState } from 'react'
import { Check, CircleHelp, Clock3, MapPin, MessageSquareText, Trash2, X } from 'lucide-react'
import { Avatar } from './Avatar'
import type { Availability, AvailabilityStatus, Profile } from '../types'
import { longDateLabel } from '../lib/date'

interface DayDialogProps {
  day: string
  profiles: Profile[]
  availability: Availability[]
  currentUserId: string
  busy: boolean
  onClose: () => void
  onSave: (status: AvailabilityStatus | null, note: string, place: string) => Promise<void>
}

const statusLabels: Record<AvailabilityStatus, string> = {
  available: 'Pasuje mi',
  unsure: 'Jeszcze nie wiem',
  unavailable: 'Nie da rady',
}

export function DayDialog({
  day,
  profiles,
  availability,
  currentUserId,
  busy,
  onClose,
  onSave,
}: DayDialogProps) {
  const ownEntry = availability.find((entry) => entry.user_id === currentUserId)
  const [status, setStatus] = useState<AvailabilityStatus | null>(ownEntry?.status || null)
  const [note, setNote] = useState(ownEntry?.note || '')
  const [place, setPlace] = useState(ownEntry?.place || '')

  useEffect(() => {
    setStatus(ownEntry?.status || null)
    setNote(ownEntry?.note || '')
    setPlace(ownEntry?.place || '')
  }, [ownEntry, day])

  const profileMap = useMemo(() => new Map(profiles.map((profile) => [profile.id, profile])), [profiles])
  const answeredPeople = availability
    .map((entry) => ({ entry, profile: profileMap.get(entry.user_id) }))
    .filter((item): item is { entry: Availability; profile: Profile } => Boolean(item.profile))
    .sort((a, b) => a.profile.display_name.localeCompare(b.profile.display_name, 'pl'))

  const missingPeople = profiles.filter((profile) => !availability.some((entry) => entry.user_id === profile.id))

  const submit = async (event: FormEvent) => {
    event.preventDefault()
    if (!status) return
    await onSave(status, note.trim(), place.trim())
  }

  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={onClose}>
      <section className="dialog" role="dialog" aria-modal="true" aria-labelledby="day-dialog-title" onMouseDown={(event) => event.stopPropagation()}>
        <button className="icon-button dialog-close" type="button" onClick={onClose} aria-label="Zamknij">
          <X size={21} />
        </button>
        <p className="eyebrow">Odpowiedzi grupy</p>
        <h2 id="day-dialog-title">{longDateLabel(day)}</h2>

        <div className="people-list">
          {answeredPeople.length === 0 ? (
            <p className="empty-state">Nikt jeszcze nie odpowiedział dla tego dnia.</p>
          ) : answeredPeople.map(({ profile, entry }) => (
            <article className="person-row" key={profile.id}>
              <Avatar profile={profile} />
              <div>
                <strong>{profile.display_name}{profile.id === currentUserId ? ' (Ty)' : ''}</strong>
                <p className="entry-status">
                  {entry.status === 'available' && <Check size={14} />}
                  {entry.status === 'unsure' && <CircleHelp size={14} />}
                  {entry.status === 'unavailable' && <X size={14} />}
                  {statusLabels[entry.status]}
                </p>
                {entry.note ? (
                  <p className="entry-detail"><Clock3 size={14} /> {entry.note}</p>
                ) : (
                  <p className="entry-detail muted-detail"><MessageSquareText size={14} /> Bez dodatkowych uwag</p>
                )}
                {entry.place && <p className="entry-detail"><MapPin size={14} /> {entry.place}</p>}
              </div>
            </article>
          ))}
        </div>

        {missingPeople.length > 0 && (
          <p className="missing-people">
            Nie odpowiedzieli: {missingPeople.map((profile) => profile.display_name).join(', ')}
          </p>
        )}

        <form className="own-availability" onSubmit={submit}>
          <fieldset className="status-fieldset">
            <legend>Twoja odpowiedź</legend>
            <div className="status-options">
              <label className={`status-option${status === 'available' ? ' selected' : ''}`}>
                <input type="radio" name="status" value="available" checked={status === 'available'} onChange={() => setStatus('available')} />
                <Check size={19} />
                <span><strong>Pasuje mi</strong><small>Termin jest dla mnie odpowiedni.</small></span>
              </label>
              <label className={`status-option${status === 'unsure' ? ' selected' : ''}`}>
                <input type="radio" name="status" value="unsure" checked={status === 'unsure'} onChange={() => setStatus('unsure')} />
                <CircleHelp size={19} />
                <span><strong>Jeszcze nie wiem</strong><small>Potrzebuję czasu na potwierdzenie.</small></span>
              </label>
              <label className={`status-option${status === 'unavailable' ? ' selected' : ''}`}>
                <input type="radio" name="status" value="unavailable" checked={status === 'unavailable'} onChange={() => setStatus('unavailable')} />
                <X size={19} />
                <span><strong>Nie da rady</strong><small>Ten termin mi nie odpowiada.</small></span>
              </label>
            </div>
          </fieldset>

          <label>
            <span className="label-with-icon"><Clock3 size={16} /> Godziny / uwagi</span>
            <textarea
              value={note}
              onChange={(event) => setNote(event.target.value.slice(0, 200))}
              placeholder="np. po 18:00, muszę jeszcze potwierdzić…"
              rows={3}
              disabled={!status}
            />
            <small className="character-count">{note.length}/200</small>
          </label>

          <label>
            <span className="label-with-icon"><MapPin size={16} /> Miejsce / propozycja</span>
            <input
              value={place}
              onChange={(event) => setPlace(event.target.value.slice(0, 120))}
              placeholder="np. Wrocław, Rynek albo okolice centrum"
              maxLength={120}
              disabled={!status}
            />
            <small className="character-count">{place.length}/120</small>
          </label>

          <div className="dialog-actions">
            <button className="primary-button" disabled={busy || !status}>
              <Check size={18} /> {busy ? 'Zapisywanie…' : 'Zapisz odpowiedź'}
            </button>
            {ownEntry && (
              <button className="danger-button" type="button" disabled={busy} onClick={() => void onSave(null, '', '')}>
                <Trash2 size={18} /> Usuń odpowiedź
              </button>
            )}
          </div>
        </form>
      </section>
    </div>
  )
}
