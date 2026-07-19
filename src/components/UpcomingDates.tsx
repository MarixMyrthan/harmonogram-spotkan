import { CalendarCheck2, Mail } from 'lucide-react'
import { useMemo } from 'react'
import { longDateLabel } from '../lib/date'
import { findUpcomingDates } from '../lib/upcomingDates'
import type { Availability, Profile } from '../types'

interface UpcomingDatesProps {
  profiles: Profile[]
  availability: Availability[]
}

export function UpcomingDates({
  profiles,
  availability,
}: UpcomingDatesProps) {
  const dates = useMemo(
    () => findUpcomingDates(profiles, availability),
    [availability, profiles],
  )

  const profileById = useMemo(
    () => new Map(profiles.map((profile) => [profile.id, profile])),
    [profiles],
  )

  return (
    <section
      className="upcoming-card"
      aria-labelledby="upcoming-dates-title"
    >
      <div className="upcoming-card-heading">
        <div>
          <p className="eyebrow">
            <CalendarCheck2 size={15} /> Najbliższy termin
          </p>

          <h1 id="upcoming-dates-title">
            Najbliższe możliwe spotkania
          </h1>
        </div>
      </div>

      {dates.length === 0 ? (
        <p className="upcoming-empty">
          Nie ma jeszcze przyszłego dnia, na który odpowiedzieli wszyscy
          i nikt nie wybrał „Nie da rady”.
        </p>
      ) : (
        <div className="upcoming-table-wrap">
          <table className="upcoming-table">
            <thead>
              <tr>
                <th>Termin</th>
                <th>Uczestnicy</th>
              </tr>
            </thead>

            <tbody>
              {dates.map((date) => (
                <tr key={date.day}>
                  <td>
                    <time dateTime={date.day}>
                      {longDateLabel(date.day)}
                    </time>
                  </td>

                  <td>
                    <div className="mini-names upcoming-participants">
                      <div className="mini-name-list">
                        {date.entries.map((entry) => {
                          const hasExtraInfo = Boolean(
                            entry.note?.trim() || entry.place?.trim(),
                          )

                          return (
                            <span
                              className={`status-pill status-${entry.status}`}
                              key={entry.user_id}
                              title={
                                hasExtraInfo
                                  ? 'Dodano godziny, uwagę lub propozycję miejsca'
                                  : undefined
                              }
                            >
                              {
                                profileById.get(entry.user_id)
                                  ?.display_name
                              }

                              {hasExtraInfo && (
                                <Mail
                                  className="note-indicator"
                                  size={11}
                                  aria-hidden="true"
                                />
                              )}
                            </span>
                          )
                        })}
                      </div>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
