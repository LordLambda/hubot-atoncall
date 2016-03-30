chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'atoncall', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/atoncall')(@robot)

  it 'registers a respond listener', ->
    expect(@robot.respond).to.have.been.calledWith(/clear on-?call cache/i)

  it 'registers a hear listener', ->
    expect(@robot.hear).to.have.been.calledWith(/@on-?call/i)
