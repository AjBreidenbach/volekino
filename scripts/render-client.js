const pug = require('pug')
const sass = require('sass')
const {minify} = require('terser')
const Path = require('path')
const fs = require('fs')



const production = process.argv.includes('prod')

const filters = {
  sass: function(data, _options) {
    let includePaths = [Path.join(process.cwd(), 'client', 'styles')]
    let options = Object.assign({data, includePaths}, _options)
    
    let result =  sass.renderSync(options).css.toString()

    return result
  }
}

const indexFile = Path.join(process.cwd(), "client", "index.pug")


const destFile = Path.join(process.cwd(), "dist", "index.html")

if(production)
  fs.appendFileSync(Path.join(process.cwd(), "dist", "client.js"), '')
else
  fs.appendFileSync(Path.join(process.cwd(), "dist", "client.min.js"), '')



const out = pug.renderFile(indexFile, {filters, production})


fs.writeFileSync(destFile, out)
