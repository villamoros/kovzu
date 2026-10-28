# Días hábiles (lunes a viernes). Los festivos de Colombia quedan pendientes.
module BusinessDays
  module_function

  def add(date, days)
    date = date.to_date
    days.times { date = next_day(date) }
    date
  end

  # Días hábiles desde `from` (sin contarlo) hasta `to` (contándolo). Negativo si `to` ya pasó.
  def between(from, to)
    from, to = from.to_date, to.to_date
    return -between(to, from) if to < from

    ((from + 1)..to).count { |day| weekday?(day) }
  end

  def weekday?(date) = !date.saturday? && !date.sunday?

  def next_day(date)
    date += 1
    date += 1 until weekday?(date)
    date
  end
end
