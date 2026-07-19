import { CalendarCheck2, CircleHelp, PartyPopper } from 'lucide-react'
import { useMemo } from 'react'
import { longDateLabel } from '../lib/date'
import { findUpcomingDates } from '../lib/upcomingDates'
import type { Availability, Profile } from '../types'

interface UpcomingDatesProps {
  profiles: Profile[]
  availability: Availability[]
}

export function UpcomingDates({ profiles, availability }: UpcomingDatesProps) {
  const dates = useMemo(
    () => findUpcomingDates(profiles, availability),
    [availability, profiles],
  )

  return (
    <section className="upcoming-card" aria-labelledby="upcoming-dates-title">
      <div className="upcoming-card-heading">
        <div>
          <p className="eyebrow"><CalendarCheck2 size={15} /> Najbliższy termin</p>
          <h1 id="upcoming-dates-title">Najbliższe możliwe spotkania</h1>
        </div>
      </div>

      {dates.length === 0 ? (
        <p className="upcoming-empty">Nie ma jeszcze przyszłego dnia, na który odpowiedzieli wszyscy i nikt nie wybrał „Nie da rady”.</p>
      ) : (
        <div className="upcoming-table-wrap">
          <table className="upcoming-table">
            <thead>
              <tr>
                <th>Termin</th>
                <th>Stan grupy</th>
              </tr>
            </thead>
            <tbody>
              {dates.map((date) => (
                <tr key={date.day}>
                  <td><time dateTime={date.day}>{longDateLabel(date.day)}</time></td>
                  <td>
                    {date.unsureCount === 0 ? (
                      <span className="upcoming-status confirmed"><PartyPopper size={16} /> Wszystkim pasuje</span>
                    ) : (
                      <span className="upcoming-status pending">
                        <CircleHelp size={16} /> {date.availableCount} {date.availableCount === 1 ? 'osobie pasuje' : 'osobom pasuje'} · {date.unsureCount} {date.unsureCount === 1 ? 'osoba jeszcze nie wie' : 'osób jeszcze nie wie'}
                      </span>
                    )}
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

