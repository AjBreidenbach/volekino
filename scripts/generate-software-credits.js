#!/usr/bin/env node
const 
  fs = require('fs'),
  https = require('https'),
  path = require('path'),
  marked = require('marked'),
  {parse} = require('node-html-parser')

let credits = fs.readFileSync('README.md', {encoding: 'UTF-8'}).split('#').find(s => s.startsWith(' Software Credits'))

credits = parse(marked.parse('# ' + credits))
//console.log(credits)
let licenseNodes = credits.querySelectorAll('a[href*="LICENSE"]')
let complete = 0
for (let node of licenseNodes) {
  //console.log(node)
  let 
    bufs = []
  function handleRequest(url) {
    let req = https.request(url, res => {
      if (res.statusCode == 302) {
        return handleRequest(res.headers.location)
      }

      res.on('data', d =>
        bufs.push(d)
      )
      res.on('end', d => {
        node.replaceWith('<br><pre style="overflow: auto;">' + marked.parse(Buffer.concat(bufs).toString()) + '</pre>')
        //console.log(Buffer.concat(bufs).toString())
        if (++complete == licenseNodes.length) {
          fs.writeFileSync(path.join('userdata', 'logs', 'software_credits'), credits.toString())
          //console.log('all done')
        }
      })
    })
    req.end()
  }
  handleRequest(node._attrs.href)

}

