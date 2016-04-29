# hubot-pingboard

A hubot script for interacting with Pingboard.com

See [`src/pingboard.coffee`](src/pingboard.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-pingboard --save`

Then add **hubot-pingboard** to your `external-scripts.json`:

```json
[
  "hubot-pingboard"
]
```

## Sample Interaction

```
user1>> hubot who's out?
hubot>>
## Remote

- Alex Gunther (5:00am - 11:00am), at Coffee Shop

## Sick

- Trip Dissywig (all day)
- Super Sadperson (all day), sick so bad

## Vacation

- Seeyou Later (all day), HAHA I'M OUT

## Business Trip

- Mr. Business (all day), Gone Gone Gone

user1>> hubot list projects
hubot>> 

- Project 1: Person1, Person2
- Project 2: Person3

user1>> hubot what's person1 working on?
hubot>> Person1: Project1, Person2
```
