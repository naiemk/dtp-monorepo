import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['cjs'],
  target: 'node18',
  platform: 'node',
  bundle: true,
  minify: false,
  sourcemap: false,
  clean: true,
  outDir: 'dist',
  splitting: false,
  treeshake: true,
  external: [],
  banner: {
    js: '#!/usr/bin/env node'
  }
});

