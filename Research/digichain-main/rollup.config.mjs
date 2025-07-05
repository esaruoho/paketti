import terser from '@rollup/plugin-terser';

export default {
    input: 'src/main.js',
    output: {
        dir: 'latest',
        format: 'cjs'
    },
    plugins: [terser()]
};
