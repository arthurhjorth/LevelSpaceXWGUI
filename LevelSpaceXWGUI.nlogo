extensions [ls table string ]


globals [
  tasks ;; this is a table that contains all custom made tasks (i.e. left hand side stuff)
  relationships ;; this is a table that contains all relationships (i.e. center stuff)
  test-var
  relationship-counter
]


to setup
  ca
  ls:reset
  set tasks table:make
  set relationships table:make
  set relationship-counter 0
  load-and-setup-model "arg-test.nlogo"
  load-and-setup-model "Wolf Sheep Predation.nlogo"
  load-and-setup-model "Climate Change.nlogo"
  ls:close 0
  ls:ask 1 "set grass? true"
  ls:ask [1 2] "setup"
  ls:show 1
  ls:show 2
end

to go
  run-relationships
end

to simulate-eco-ls-system
  setup
  ;; user chooses WSP model (model 1)
  ;; clicks "select some agents"
  ;; names their new variable 'gassy-turtles'
  ;; writes "trltes with [energy > 5]"
  ;; Clicks OK. This is then run:
  add-entity "1-gassy-turtles" new-entity 1 "turtles with [energy > 50]" [] "agentset" "OTPL"
  add-entity "1-gassiness" new-entity 1 "energy / 5" [] "value" "T"
  ;; user chooses CC model (model 2)
  ;; chooses "calculate value"
  ;; calls their new variable "new grass regrowth time"
  ;; writes "(20 + abs (72 - temperature ))"
  ;; clicks OK, this then runs:
  add-entity "2-new-grass-regrowth-time" new-entity 2 "(20 + abs (72 - temperature ))" [] "value" "OTPL"
  ;; user chooses CC model (model 2)
  ;; chooses "calculate value"
  ;; calls their new variable "new grass regrowth time"
  ;; writes "(20 + abs (72 - temperature ))"
  ;; clicks OK, this then runs:  
  add-entity "2-remove-some-co2" new-entity 2 "repeat n [remove-CO2]" ["n"] "command" "OTPL"
  add-entity "1-grass" new-entity 1 "count patches with [ pcolor = green ] / 100" [] "value" "OTPL"
  add-entity "2-add-some-co2" new-entity 2 "repeat n [add-CO2]" ["n"] "command" "OTPL"
  
  ;; this asks WSP to call its own go every tick
  add-ls-interaction-between "1:Wolf Sheep Predation.nlogo" [] "1-GO" []
  ;; this asks cc to call its own go every tick
  add-ls-interaction-between "2:Climate Change.nlogo" [] "2-GO" []
  ;; this creates an interaction between gassy turtles (agentset) and add-co2 (observer command)
  add-ls-interaction-between "1-gassy-turtles" [] "2-add-some-co2" (list get-task entity "1-gassiness")
  ;; this creates a relationship between new grass regrowth time (value) and grass-regrowth-time (value)
  add-ls-interaction-between "2-new-grass-regrowth-time" [] "1-GRASS-REGROWTH-TIME" []
  ; this creates a relationship between the cc model (observer) and a command in itself (command)
  add-ls-interaction-between "2:Climate Change.nlogo" [] "2-remove-some-co2" (list get-task entity "1-grass")
  
end


to run-relationships
  foreach table:to-list relationships [
    run first last ?
  ]
end

to-report make-variadic-task [astring args]
  let arg-no 0
  let sb []
  foreach string:rex-split astring " " [
    ifelse member? ? args[
      set sb lput (word "(item " (position ? args) " ?)") sb
    ]
    [
      set sb lput ? sb      
    ]  
  ]
  report string:from-list sb
end


to-report new-entity [model task-string args the-type permitted-contexts]
  set task-string (make-variadic-task task-string args)
  let task-table table:make
  table:put task-table "model" model
  table:put task-table "to-string" task-string
  table:put task-table "args" args
  table:put task-table "type" the-type
  table:put task-table "contexts" permitted-contexts
  show task-string
  let task-from-model ls:report model (word "task [ " task-string " ]")  
  ;; in terms of knowing how to compile the tasks, we need to know two things:
  ;; first, is it a command or a reporter - this is in the 'the-type' variable
  ;; second, is it runnable from the Observer context. 
  ;; Observer commands/reporters need to be compiled like this:
  ;;;;; task [ls:report model task-string]    
  ;; non-observer ones need to be compiled like thi:
  ;;;;; ls:report model (word "task [ " task-string " ]")  
  
  ifelse is-reporter-task? task-from-model
  [
    ;; observer reproters here
    ifelse member? "O" permitted-contexts[
      table:put task-table "to-task" task [(ls:report model task-string ?)]    
    ]
    ;; turtle reporters here
    [
      table:put task-table "to-task" ls:report model (word "task [ " task-string " ]")  
    ]
  ]
  ;; or it is a command task\
  [
    ;; observer commands are command tasks that are compiled in the observer of the parent model,
    ifelse member? "O" permitted-contexts[
      table:put task-table "to-task" task [(ls:ask model task-string ?)]
    ]
    ;; turtle commands here:
    [
      ;; turtle commands are tasks that are compiled in the context of the child model's observer
      table:put task-table "to-task" ls:report model (word "task [ " task-string " ]")
    ]
  ]
  report task-table
end


to-report get-eligible-interactions [an-entity]
  let the-type table:get an-entity "type"
  print an-entity
  ;; if it's an observer, they can call observer commands in their own model
  if the-type = "observer"[
    report filter [
      table:get last ? "type" = "COMMAND" and 
      member? "O" table:get last ? "contexts" 
    ] table:to-list tasks 
  ]  
  ;; if it's an agentset, they can call turtle commands in their own model or observer commands in other models
  if the-type = "agentset"[
    report filter [
      (table:get last ? "type" = "COMMAND" and 
      member? "T" table:get last ? "contexts" and
      table:get last ? "model" = table:get an-entity "model"
      )
      or
      table:get last ? "type" = "COMMAND" and 
      member? "O" table:get last ? "contexts"  and     
      table:get last ? "model" != table:get an-entity "model"
    ] table:to-list tasks 
  ]
  if the-type = "value"[
    report filter [
      table:get last ? "type" = "value"
    ] table:to-list tasks 
  ]  
  report (list "poop")
end



to load-and-setup-model [model-path]
  let the-model 0
  (ls:load-gui-model model-path [set the-model ?])
  ;; add the observer of the model
  add-observer the-model
  ;; add all a models procedures
  add-model-procedures the-model
  ;; and globals
  add-model-globals the-model
  ;; and breeds
  add-model-breeds the-model
  
end

to add-observer [the-model]
  let name (word the-model ":" ls:name-of the-model)
  let the-type "observer"
  ;; observers are different so we just manually create them here 
  let observer-entity table:make
  table:put observer-entity "model" the-model
  table:put observer-entity "type" the-type
  table:put tasks name observer-entity
  
end

to add-model-procedures [the-model]
  foreach ls:_model-procedures the-model [
    let procedure-name first ?
    let args last ?
    let the-type item 1 ?
    print args
    let args-string ""
    ;; procedures always have postfix argument, so this is easy: 
    repeat length args [set args-string (word args-string " ?")]
    let task-string (word procedure-name args-string)
    add-entity (word the-model "-" procedure-name) new-entity the-model task-string args the-type item 2 ?
  ]
end

to add-model-globals [the-model]
  foreach ls:_globals the-model [
    let global-name ?
    let args []
    ;; not sure if these should be reporters (which they technically are) or 'globals' since we probably don't want to SET 
    ;; reporters, but we may want to set globals?
    ;; setting to value now, might not be right though......
    let the-type "value"
    add-entity (word the-model "-" global-name) new-entity the-model global-name args the-type "OTLP"
  ]
end

to add-model-breeds [the-model]
  foreach map [first ?] ls:_list-breeds the-model [
    let agents ?
    let args []
    ;; not sure if these should be reporters (which they technically are) or 'globals' since we probably don't want to SET 
    ;; reporters, but we may want to set globals?
    ;; setting to value now, might not be right though......
    let the-type "agentset"
    add-entity (word the-model "-" agents) new-entity the-model agents args the-type "OTLP"
    
  ]
end



to-report all-observers
  
end

to-report tasks-with [afilter]
  
end

to add-ls-interaction-between  [entity1 ent1args entity2 ent2args]
  let first-entity entity entity1 
  let second-entity entity entity2
  
  let first-entity-type table:get first-entity "type"
  let second-entity-type table:get second-entity "type"
  if (first-entity-type = "agentset")[
    if second-entity-type = "COMMAND"[
      ; if an agenset interacts with a command, each member of the agenset calls the command
      let atask task [
        ask (run-result get-task first-entity (map runresult ent1args)) [
          (run get-task second-entity (map runresult ent2args))
        ]
      ]
      add-relationship atask entity1 entity2
    ]
  ]
  if first-entity-type = "observer"[
    if second-entity-type = "command" or second-entity-type = "COMMAND" [
      show first-entity
      show second-entity
      let the-observer-id get-model first-entity
      let the-command get-string second-entity
      let the-task task [(ls:ask the-observer-id the-command (map [(runresult ? [])] ent2args))]
      add-relationship the-task entity1 entity2
    ]
  ]
end

to-report all-relationships
  report map [?] table:to-list relationships
end


;;; accessing tasks and relationships
to-report get-task [the-entity]
  report table:get the-entity "to-task"
end

to-report get-string [the-entity]
  report table:get the-entity "to-string"
end

to-report get-model [the-entity]
  report table:get the-entity "model"
end

to-report entity [entity-name]
  ;  print entity-name
  report table:get tasks entity-name
end

to add-relationship [atask entity1-name entity2-name]
  table:put relationships relationship-counter (list atask entity1-name entity2-name)
  set relationship-counter relationship-counter + 1
end

to add-entity [name atask-table]
  table:put tasks name atask-table
end

to-report all-agent-entities
  report filter [table:get last ? "type" = "agentset" or table:get last ? "type" = "observer"] table:to-list tasks 
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
649
470
16
16
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

OUTPUT
674
33
923
471
12

BUTTON
58
78
121
111
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
23
196
56
NIL
simulate-eco-ls-system
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## notes
if a learner constructs a boolean reporter, they can create 'if' scenarios. 



this works
let atask ls:report 1 "task [move]" ask ls:report 1 "sheep" [run atask]
but 
let atask get-task entity "1-MOVE"
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2-RC3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
