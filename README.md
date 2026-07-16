# WaziBet

A real-time betting platform with live football simulation.

## Technologies

- **Phoenix** - Web framework
- **PostgreSQL** - Database
- **Oban** - Background job processing
- **GenServer** - Game simulation engine
- **Canada** - Role-based access control
- **Decimal Odds** - Odds reflect implied probability; probabilities convert to odds using the formula: odds = 1/probability
- **Poisson Distribution** - Simulates goal scoring by calculating probability of goals based on team strength ratings

## Getting Started

```bash
mix setup
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000)
