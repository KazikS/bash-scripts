#!/bin/bash

# Установка правил остановки при получении ошибки
set -eou pipefail

# Получение имени проекта из первого аргумента введенного в строку
PROJECT_NAME=$1

# Проверка на существование такой папки
if [ -e "$PROJECT_NAME" ]
then
echo "Проект $PROJECT_NAME уже существует"
exit 1
fi

# Создание проекта
npm create vite@latest $PROJECT_NAME -- --template react-ts --eslint --no-immediate --no-interactive
cd $PROJECT_NAME
# Очистка от шаблонных файлов и кода
rm -rf  public/favicon.svg \
        public/icons.svg \
        src/assets \
        src/*.css \
        src/App.tsx

# Установка нужных зависимостей
printf '\033[36m%s\033[0m\n' "Установка npm зависимостей"
npm install
npm install @chakra-ui/react @emotion/react react-router

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
import { AppRouter } from './routes/AppRouter';

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
});

fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n")
EOF

printf '\033[32m%s\033[0m\n' "Проект $PROJECT_NAME создан ✅"