import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        vector: {
          surface: '#0A0A0A',
          card: '#141414',
          border: '#2A2A2A',
          primary: '#00FF88',
          danger: '#FF4444',
          neutral: '#888888',
          muted: '#666666',
        },
        position: {
          bull: '#00FF88',
          bear: '#FF4444',
          yield: '#FFD700',
          volLong: '#8888FF',
          volShort: '#FF88FF',
        },
      },
      fontFamily: {
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
        mono: ['var(--font-jetbrains)', 'JetBrains Mono', 'monospace'],
      },
    },
  },
  plugins: [],
};

export default config;
