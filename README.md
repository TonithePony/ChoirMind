# ChoirMind

**Helping Every Singer Find Their Voice Through Artificial Intelligence**

ChoirMind is an AI-powered choir rehearsal and music education platform that transforms AI from an evaluation tool into an educational partner — helping singers grow with confidence while preserving the collaborative spirit of ensemble music.

## Features

| Feature                           | Description                                                                     |
|-----------------------------------|---------------------------------------------------------------------------------|
| **Intelligent Pitch Analysis**    | Real-time pitch detection with pattern recognition (flat ascents, sharp drifts) |
| **Rhythm & Timing Coach**         | Detects early entrances, delayed attacks, and tempo instability                 |
| **AI Vocal Coach**                | Personalized conductor-style feedback powered by LLMs                           |
| **Harmony Simulation**            | Practice your part while AI generates remaining choir voices                    |
| **Virtual Choir**                 | Synchronize recordings from multiple singers into ensemble performances         |
| **Conductor Dashboard**           | Ensemble analytics: pitch stability, rhythm, difficult passages                 |
| **Growth Journal**                | Progress-focused reflection summaries after every rehearsal                     |

## Quick Start

### Prerequisites

- Node.js 18+
- Python 3.10+
- (Optional) OpenAI API key for AI coach feedback

### One-command setup

From the project root, run the setup script once:

**macOS / Linux:**

```bash
chmod +x setup.sh start.sh   # first time only
./setup.sh
```

**Windows (PowerShell):**

```powershell
.\setup.ps1
```

This will:

- Check Node.js and Python versions
- Create `web/.env` and `web/.env.local` from the template
- Install npm and Python dependencies
- Initialize and seed the SQLite database
- Set up the Python virtual environment for audio analysis

Optionally pass your OpenAI key during setup:

```bash
OPENAI_API_KEY=sk-... ./setup.sh
```

### Run the app

Start both services (web + analysis backend):

```bash
./start.sh          # macOS / Linux
.\start.ps1         # Windows
```

Or start them separately:

```bash
# Web app (required)
cd web && npm run dev
# → http://localhost:3000

# Analysis backend (optional, enhanced pitch/rhythm)
cd backend && source venv/bin/activate && uvicorn main:app --reload --port 8000
# → http://localhost:8000/docs   (interactive API docs)
# → http://localhost:8000/health (health check)
```

> **Note:** Port 8000 is an API server, not a web page. Open `/docs` or `/health` — not the bare root URL before the fix. The main ChoirMind UI is at **http://localhost:3000**.

### Troubleshooting port 8000

If `http://localhost:8000` doesn't work:

1. **Start the backend manually** (in a separate terminal):
   ```bash
   cd backend
   source venv/bin/activate
   uvicorn main:app --reload --port 8000
   ```
   If `venv` doesn't exist, run `./setup.sh` first.

2. **Verify it's running:**
   ```bash
   curl http://localhost:8000/health
   ```
   Expected: `{"status":"ok","service":"choirmind-analysis"}`

3. **Use the correct URLs:**
   | URL                          | Purpose                    |
   |------------------------------|----------------------------|
   | http://localhost:3000        | Main ChoirMind app         |
   | http://localhost:8000/docs   | Analysis API documentation |
   | http://localhost:8000/health | Backend health check       |

4. **Port already in use?** Kill the old process:
   ```bash
   lsof -ti :8000 | xargs kill
   ```

### Environment Variables

Created automatically by `setup.sh` from `web/.env.example`:

```env
DATABASE_URL="file:./dev.db"
OPENAI_API_KEY=sk-...          # Optional: enables AI vocal coach
ANALYSIS_API_URL=http://localhost:8000  # Optional: Python analysis backend
```

## Project Structure

```
choirmind/
├── web/                 # Next.js frontend + API routes
│   ├── prisma/          # Database schema
│   └── src/
│       ├── app/         # Pages & API
│       ├── components/  # UI components
│       └── lib/         # Audio, pitch, coach utilities
└── backend/             # FastAPI audio analysis service
    └── analysis/        # Pitch & rhythm algorithms
```

## Tech Stack

- **Frontend:** Next.js 15, React 19, Tailwind CSS, Web Audio API
- **Backend:** FastAPI, librosa, numpy (pitch & rhythm analysis)
- **Database:** SQLite via Prisma
- **AI:** OpenAI GPT (with rule-based fallback)
