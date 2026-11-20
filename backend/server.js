require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const OpenAI = require('openai');

const MOCK = process.env.MOCK === 'true';

if (!process.env.OPENAI_API_KEY && !MOCK) {
  console.error('Не задан OPENAI_API_KEY в файле .env');
  process.exit(1);
}

const app = express();
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY || 'mock-key',
  timeout: 25000,
});

app.use(cors());
app.use(express.json({ limit: '1mb' }));
// Журнал запросов: в консоль и в файл
app.use(morgan('dev'));
app.use(morgan('combined', { stream: fs.createWriteStream('requests.log', { flags: 'a' }) }));
// Ограничение: 20 запросов в минуту с одного IP
app.use('/api/', rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  message: { success: false, error: 'Слишком много запросов. Подождите минуту.' },
}));

// System Prompt для разных ролей
const ROLES = {
  consultant: 'Ты — вежливый универсальный консультант. Отвечай кратко, понятно и по делу.',
  teacher: 'Ты — терпеливый преподаватель. Объясняй простыми словами, приводи примеры и проверяй понимание.',
  programmer: 'Ты — опытный программист. Давай точные ответы с примерами кода и пояснениями.',
  translator: 'Ты — профессиональный переводчик. Переводи текст точно, сохраняя стиль и смысл.',
};

// Хранение истории переписки (JSON-файл)
const FILE = 'history.json';
let db = fs.existsSync(FILE) ? JSON.parse(fs.readFileSync(FILE, 'utf8')) : {};
const saveDb = () => fs.writeFileSync(FILE, JSON.stringify(db, null, 2));

app.post('/api/chat', async (req, res) => {
  const { message, conversationId, role = 'consultant' } = req.body || {};

  // Валидация
  if (typeof message !== 'string' || !message.trim() || message.length > 4000) {
    return res.status(400).json({ success: false, error: 'Некорректное сообщение (1–4000 символов)' });
  }
  if (typeof conversationId !== 'string' || !/^[\w-]{1,64}$/.test(conversationId)) {
    return res.status(400).json({ success: false, error: 'Некорректный conversationId' });
  }

  const history = (db[conversationId] ||= []);
  history.push({ role: 'user', content: message.trim() });

  try {
    let reply;

    if (MOCK) {
      // Тестовый режим без OpenAI (только для отладки интерфейса)
      reply = `[Тестовый ответ] Вы написали: «${message.trim()}»`;
    } else {
      const completion = await openai.chat.completions.create({
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        temperature: 0.7,
        messages: [
          { role: 'system', content: ROLES[role] || ROLES.consultant },
          ...history.slice(-20), // контекст: последние 20 сообщений
        ],
      });
      reply = completion.choices[0].message.content;
    }

    history.push({ role: 'assistant', content: reply });
    saveDb();
    res.json({ success: true, reply, conversationId });
  } catch (err) {
    history.pop(); // убираем сообщение, на которое не получили ответ
    console.error('OpenAI error:', err.status, err.message);

    let status = 500;
    let error = 'Внутренняя ошибка сервера';
    if (err.status === 401) {
      error = 'Неверный API-ключ OpenAI';
    } else if (err.status === 429) {
      status = 429;
      error = 'Превышен лимит OpenAI. Попробуйте позже.';
    } else if (err.name === 'APIConnectionTimeoutError') {
      status = 504;
      error = 'OpenAI не ответил вовремя';
    }
    res.status(status).json({ success: false, error });
  }
});

// Получить историю диалога (на сервере)
app.get('/api/history/:id', (req, res) => {
  res.json({ success: true, messages: db[req.params.id] || [] });
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(400).json({ success: false, error: 'Некорректный запрос' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`Сервер запущен: http://localhost:${PORT}${MOCK ? ' (ТЕСТОВЫЙ РЕЖИМ, без OpenAI)' : ''}`)
);