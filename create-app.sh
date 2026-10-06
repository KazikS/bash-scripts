#!/bin/bash

# Установка правил остановки при получении ошибки
set -eou pipefail

command -v node >/dev/null || { echo "Нужен Node.js" >&2; exit 1; }
node -e 'process.exit(+process.versions.node.split(".")[0] >= 20 ? 0 : 1)' \
  || { echo "Нужен Node.js >= 20" >&2; exit 1; }

# Получение имени проекта из первого аргумента введенного в строку
PROJECT_NAME=${1:-}

# Проверка на существование такой папки
if [ -e "$PROJECT_NAME" ]; then
  echo "Использование: $0 <имя-проекта>" >&2
  exit 1
fi

# Создание проекта
npm create vite@9.2.1 "$PROJECT_NAME" -- --template react-ts --eslint --no-immediate --no-interactive
trap 'rm -rf "$PROJECT_NAME"' ERR
cd "$PROJECT_NAME"
# Очистка от шаблонных файлов и кода
rm -rf  public/favicon.svg \
        public/icons.svg \
        src/assets \
        src/*.css \
        src/App.tsx

# Установка нужных зависимостей
printf '\033[36m%s\033[0m\n' "Установка npm зависимостей"
# разделить runtime и dev
npm install @chakra-ui/react @emotion/react react-router @reduxjs/toolkit react-redux
npm install -D vitest jsdom @testing-library/react @testing-library/dom \
               @testing-library/jest-dom @testing-library/user-event

# Создание архитектуры FSD
mkdir -p src/{app,entities,features,widgets,shared,test,store,pages}
mkdir -p src/app/{router,Layout}

#Настройка chakra
npx --yes @chakra-ui/cli snippet add
mkdir -p src/shared/theme
mv src/components/ui/{color-mode.tsx,provider.tsx,toaster.tsx,tooltip.tsx} src/shared/theme
rm -rf src/components

# Создание базовых файлов
cat > "src/app/App.tsx" << 'EOF'
import { AppRouter } from './router/AppRouter';

function App() {
  return <AppRouter />;
}

export default App;

EOF

cat > "src/app/router/AppRouter.tsx" << 'EOF'
import { createBrowserRouter } from 'react-router';
import { RouterProvider } from 'react-router/dom';
import { Layout } from '@/app/Layout';


const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [],
  },
]);

export const AppRouter = () => {
  return <RouterProvider router={router} />;
};

EOF

cat > "src/app/Layout/Layout.tsx" << 'EOF'
import { Flex } from '@chakra-ui/react';
import { Outlet } from 'react-router';

export const Layout = () => {
  return (
    <Flex flexDirection={{ base: 'column', md: 'row' }} position="relative" minH="100vh">
      <Outlet />
    </Flex>
  );
};

EOF

cat > "src/app/Layout/index.ts" << 'EOF'
export * from './Layout';

EOF

cat > "src/main.tsx" << 'EOF'
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from '@/app/App';
import { Provider } from '@/shared/theme/provider';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Provider>
      <App />
    </Provider>
  </StrictMode>,
);

EOF

cat > "vite.config.ts" << 'EOF'
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
  },
  resolve: {
    tsconfigPaths: true,
  },
});

EOF

cat > "src/shared/theme/theme.ts" << 'EOF'
import { createSystem, defineConfig, defaultConfig } from '@chakra-ui/react';


const config = defineConfig({
  theme: {/** заполнить после настройки темы */},
});

export const system = createSystem(defaultConfig, config);

EOF

cat > "src/shared/theme/provider.tsx" << 'EOF'
'use client';

import { ChakraProvider } from '@chakra-ui/react';

import { ColorModeProvider, type ColorModeProviderProps } from './color-mode';
import { system } from './theme';

export function Provider(props: ColorModeProviderProps) {
  return (
    <ChakraProvider value={system}>
      <ColorModeProvider {...props} defaultTheme="light" />
    </ChakraProvider>
  );
}

EOF

# Подгон tsconfig.app.json под Chakra UI и Vitest
node << 'EOF'
const fs = require("fs");
const ts = require("typescript");
const file = "tsconfig.app.json";

const { config, error } = ts.readConfigFile(file, ts.sys.readFile);
if (error) {
  console.error("Не удалось распарсить", file);
  process.exit(1);
};

Object.assign(config.compilerOptions, {
  target: "ESNext",
  module: "ESNext",
  moduleResolution: "Bundler",
  skipLibCheck: true,
  paths: { "@/*": ["./src/*"] },
  types: ["vite/client", "vitest/globals"],
});

fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n")
EOF

cat > ".prettierrc" << 'EOF'
{
  "printWidth": 100,
  "trailingComma": "es5",
  "singleQuote": true
}

EOF

cat > "src/test/setup.ts" << 'EOF'
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

import '@testing-library/jest-dom/vitest';

afterEach(() => {
  cleanup();
});

Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  }),
});

EOF

cat > "src/store/hooks.ts" << 'EOF'
import { useSelector, useDispatch } from 'react-redux';

import type { RootState, AppDispatch } from './store';

export const useAppSelector = useSelector.withTypes<RootState>();
export const useAppDispatch = useDispatch.withTypes<AppDispatch>();

EOF

cat > "src/store/store.ts" << 'EOF'
import { configureStore } from '@reduxjs/toolkit';

export const store = configureStore({
  reducer: {/** заполнить во время настройки хранилища */},
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

EOF

cat > "src/store/index.ts" << 'EOF'
export * from './store.ts'
EOF
trap - ERR
printf '\033[32m%s\033[0m\n' "Проект $PROJECT_NAME создан ✅"