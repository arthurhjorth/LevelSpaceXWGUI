extensions [ls table string xw ]
__includes [ "notebook.nls" ]

globals [
  tasks ;; this is a table that contains all custom made tasks (i.e. left hand side stuff)
  relationships ;; this is a table that contains all relationships (i.e. center stuff)
  setup-relationships ;; this is a table that contains all relationships that are run at setup
  test-var
  relationship-counter
  wsp
  cc
  left-column-width
  entity-serial
  relationship-serial
  setup-relationships-serial
  
]

to setup
  ca
  ls:reset
  set tasks table:make
  set relationships table:make
  set setup-relationships table:make
  
  ;; Adding a levelspace model
  let the-type "observer"
  ;; observers are different so we just manually create them here 
  let observer-entity table:make
  table:put observer-entity "to-string" "LevelSpace"
  table:put observer-entity "model" "x"
  table:put observer-entity "type" "observer"
  table:put observer-entity "args" []
  table:put observer-entity "name" "LevelSpace"
  add-entity observer-entity
  
  
  set relationship-counter 0
  load-and-setup-model "Wolf Sheep Predation.nlogo" 
  load-and-setup-model "Climate Change.nlogo"
  set wsp 0
  set cc 1
  ls:ask wsp "set grass? true"
  ls:ask wsp "setup"
  ls:ask cc "import-world \"ls-gui-setup\""
  ls:show 0
  ls:show 1
  
  set left-column []
  set left-column-width 400
  set center-column []
  
  set margin 10
  
  
  
  setup-notebook
  reset-gui
end

to draw-GUI
  draw-entity-lister
  draw-aux-buttons
  draw-relationship-builder
  draw-center
end

to draw-aux-buttons
  xw:ask "lsgui" [
    xw:create-button "reset-gui-button" [
      xw:set-label "Redraw Gui"
      xw:set-commands "reset-gui"
      xw:set-x (margin * 3) + (left-column-width * 2)
      xw:set-y margin
      xw:set-width 200
    ]   
    xw:create-button "go-once-button" [
      xw:set-label "Go once"
      xw:set-commands "run-relationships-once"
      xw:set-x (margin * 3) + (left-column-width * 2)
      xw:set-y margin + 50
      xw:set-width 200
    ]
    
    xw:create-checkbox "go-forever" [
      xw:set-label "Update commands"
      xw:set-label "go forever"
      xw:set-height 50
      xw:on-selected?-change [
        while [ [ xw:selected? ] xw:of "go-forever"]  [
          run-relationships-once
        ]
      ]
      
      xw:set-x (margin * 3) + (left-column-width * 2)
      xw:set-y margin + 100
      xw:set-width 200
    ]
    xw:create-button "load-new-model" [
      xw:set-label "Load new model"
      xw:set-commands "load-and-setup-model user-file"
      xw:set-x (margin * 3) + (left-column-width * 2)
      xw:set-y margin + 150
      xw:set-width 200
    ]
    
  ]
end

;; AH: this isc alled at the wrong times.
to draw-relationship-builder
  
  xw:ask "lsgui" 
  [
    xw:create-chooser "setup-or-go" [
      xw:set-label "Show setup or go relationships: " 
      xw:set-items ["Setup" "Go"] 
      xw:set-x margin * 2 + left-column-width
      xw:set-width left-column-width
      ;; only find the height of them all except the last because that is itself
        xw:set-y margin + sum map [[xw:height] xw:of ?] center-column
      set center-column fput "setup-or-go" center-column
      
    ]
    xw:on-change "setup-or-go" [draw-center]


  ]
end

to draw-center
  clear-center
    xw:create-relationship "new-rel" 
    [
      xw:set-color blue
      xw:set-y margin + sum map [[xw:height] xw:of ?] center-column
      xw:set-width left-column-width
      xw:set-x margin * 2 + left-column-width
      xw:set-height 250
      xw:set-save-command "save-relationship-from-gui \"new-rel\" draw-center"
      xw:set-available-agent-reporters map [(word first ? ":" name-of last ?)] all-agent-entities
      xw:set-available-procedures []
      xw:on-selected-agent-reporter-change [
        update-commands-in-gui "new-rel"
        update-agent-args "new-rel"
        xw:ask "new-rel" [
          xw:set-selected-procedure-arguments []
          xw:set-selected-agentset-arguments []
          ]
        
        ]
      xw:on-selected-procedure-change [
        update-command-args "new-rel"
        ]
      set center-column lput "new-rel" center-column    
    ]
    
    
    ;; list existing relationships; first find out if we're looking at startup or go relationships
    let the-relationships ifelse-value (xw:get "setup-or-go" = "Go") [relationships][setup-relationships]
    foreach table:to-list the-relationships [
      let relationship-id first ?
      let the-entity last ?
      let widget-name (word relationship-id)
      xw:create-relationship widget-name [
        xw:set-y margin + sum map [[xw:height] xw:of ?] center-column
        xw:set-width left-column-width
        set center-column lput (word first ?) center-column            
        xw:set-x margin * 2 + left-column-width
        xw:set-height 150
        xw:set-available-agent-reporters map [(word first ? ":" name-of last ?)] all-agent-entities
        let agent-menu-name (word table:get the-entity "agent-id" ":" table:get the-entity "agent-name" )
        xw:set-selected-agent-reporter agent-menu-name
        update-commands-in-gui widget-name
        update-agent-args widget-name
        let temp-widget-name widget-name
        xw:on-selected-agent-reporter-change [
          update-commands-in-gui temp-widget-name
          update-agent-args temp-widget-name
          xw:ask temp-widget-name [
            xw:set-selected-procedure-arguments []
            xw:set-selected-agentset-arguments []
            ]
        ]
        xw:on-selected-procedure-change [
          update-command-args temp-widget-name

        ]        
        let command-menu-name (word table:get the-entity "command-id" ":" table:get the-entity "command-name" )        
        xw:set-selected-procedure command-menu-name 
;        let relationship-type xw;; Change code here so we can delete setup relationships too. 

      ifelse xw:get "setup-or-go" = "Go"[
        xw:set-delete-command (word "delete-relationship" " " widget-name " draw-center")
        xw:set-run-command (word "run-relationship-by-id " relationship-id)
      ]  
      [
        xw:set-delete-command (word "delete-setup-relationship" " " widget-name " draw-center")        
        xw:set-run-command (word "run-setup-relationship-by-id " relationship-id)
      ]
      ]
    ]
end


;; call this when available-agent-reporters changes.
to update-commands-in-gui [a-relationship-widget]
  xw:ask a-relationship-widget [
    let chosen-agent-id first string:rex-split xw:selected-agent-reporter ":" 
    ;; we run-result because it's a string and we need a number
    show chosen-agent-id
    let chosen-agent-entity entity-from-id run-result chosen-agent-id
    xw:set-available-procedures map [(word ? ":" name-of entity-from-id ?) ] get-eligible-interactions chosen-agent-entity
  ]
end



to update-chosen-command-args [a-relationship-widget]
  xw:ask a-relationship-widget [
    ;    table:get relationships "
  ]
  
end


to update-command-args [a-relationship-widget]
  xw:ask a-relationship-widget [
    let the-entity-id runresult (first string:rex-split xw:selected-procedure ":")
    xw:set-available-procedure-arguments get-arg-tuples the-entity-id
  ]
end

to update-agent-args [a-relationship-widget]
  xw:ask a-relationship-widget [
    ;; we run-result because it's a string and we need a number
;    show run-result (first string:rex-split xw:selected-agent-reporter ":")
    let chosen-agent-id run-result (first string:rex-split xw:selected-agent-reporter ":")
;    let chosen-agent-entity entity-from-id run-result chosen-agent-id
    xw:set-available-agentset-arguments get-arg-tuples chosen-agent-id
  ]
end

to-report get-arg-tuples [identity-id]
  let an-entity entity-from-id identity-id
  let the-args get-args an-entity
  let outer []
  foreach the-args[
;    let tuple (list ? map [table:get last ? "name"] get-eligible-arguments an-entity)
    print ?
    print get-eligible-arguments an-entity
    let tuple (list ? map [(word first ? ":" table:get last ? "name")] get-eligible-arguments an-entity)
    set outer fput tuple outer
    xw:set-height xw:height + 20
  ]
  report outer
  
end


to delete-relationship [a-widget]
  table:remove relationships a-widget
end

to delete-setup-relationship [a-widget]
  table:remove setup-relationships a-widget
end

;; (map list [1 2 3] [a b c])

to save-relationship-from-gui [a-widget]
  ;; We need seven things.
  ;; The two entities, and the actuals for each of them - all from the widget.
  ;; the task being called 
  ;; the names of args, with get-args from the entities
  
  
  ;; runresults because we get a string but want id as a number
  let chosen-agent-id [first string:rex-split xw:selected-agent-reporter ":" ] xw:of a-widget
  let acting-entity entity-from-id run-result chosen-agent-id
  let acting-entity-name name-of acting-entity
  let chosen-command-id [first string:rex-split xw:selected-procedure ":" ] xw:of a-widget
  let command-entity entity-from-id run-result chosen-command-id
  let command-entity-name name-of command-entity
  
  let acting-args get-args acting-entity
  let command-args [xw:selected-procedure-arguments] xw:of  a-widget
;  show (word "command arg: " command-args)
  let acting-actuals []
  let command-actuals map [get-task entity-from-id runresult (first string:rex-split last ? ":")] [xw:selected-procedure-arguments ] xw:of  a-widget
  ;; Why do I thik we need seven? I think we just need six. Is the 7th for gui stuff?
  
  ;  show (list acting-entity command-entity acting-args command-args)
;  add-ls-interaction-between acting-entity-name acting-actuals command-entity-name command-actuals command-args acting-args
  let ls-task get-ls-task-between acting-entity-name acting-actuals command-entity-name command-actuals 
  
  
  let the-relationship add-relationship ls-task acting-entity-name acting-actuals command-entity-name command-actuals command-args acting-args chosen-agent-id chosen-command-id
  
  let relationship-type xw:get "setup-or-go"
  let the-table ifelse-value (relationship-type = "Go") [relationships] [setup-relationships]
  table:put the-table relationship-counter the-relationship
  set relationship-counter relationship-counter + 1
end


;to update-agents-in-gui
;  xw:ask "new-rel"[
;          xw:set-available-agent-reporters map [(word first ? ":" name-of last ?)] all-agent-entities
;  ]
;end
;; this is a callback procedure, called by the 1st entity selector
;; this populates the 2nd entity selector, based on what agent is selected as 'actor'

to list-eligible-entities
  ;; create a relationship widget here
  ;; we need some code in here to deal with the number 
end





to draw-entity-lister
  xw:ask "lsgui" [
    ;; create the models chooser
    xw:create-chooser "Models" [
      xw:set-label "Models" 
      xw:set-items map [name-of entity-from-id ?] map [first ?] all-observers  
      xw:set-width left-column-width
      xw:set-x margin
      xw:set-y margin
;      xw:on-selected-item-change [show-it]
      set left-column lput "Models"  left-column  
    ]
    
    xw:create-chooser "data-types" [
      xw:set-label "Show this model's entities of type: " 
      xw:set-items ["Extended Agents" "Reporters" "Commands"] 
      xw:set-x margin
      xw:set-width left-column-width
      ;; only find the height of them all except the last because that is itself
      xw:set-y margin + sum map [[xw:height] xw:of ?] butlast xw:widgets
      set left-column lput "data-types"  left-column 
    ]

  ]
  
  xw:on-change "Models" [show-it]
  xw:on-change "data-types" [show-it]
  
end

to show-it 
  ;; first remove everythign in left column except the three main buttons
  clear-left
  let the-entities [] ;; this contains all the types of this widget
  let the-type 0 ;; this goes in the 'new' entity widget
  if xw:get "data-types" = "Extended Agents"[ 
    set the-entities sentence get-from-model-all-types  table:get entity xw:get "Models" "model" "observer" get-from-model-all-types  table:get entity xw:get "Models" "model" "agentset"
    set the-type "agentset"
  ]
  if xw:get "data-types" = "Reporters"[ 
    set the-entities sentence get-from-model-all-types  table:get entity xw:get "Models" "model" "value" get-from-model-all-types  table:get entity xw:get "Models" "model" "reporter"
    set the-type "reporter"
  ]
  if xw:get "data-types" = "Commands"[ 
    set the-entities get-from-model-all-types  table:get entity xw:get "Models" "model" "command"
    set the-type "command"    
  ]
  
  
  ;; add widget for creating new entities:
  xw:create-procedure-widget "new thing" [
    xw:set-name (word "New " the-type)
    xw:set-x margin
    xw:set-height 150
    xw:set-width left-column-width
    xw:set-y margin + sum map [[xw:height] xw:of ?] left-column
    set left-column lput "new thing" left-column
    xw:set-color blue
    xw:set-save-command (word "save-entity-from-widget \"new thing\" \"new\"  show-it") 
  ]
  
;   add entities to the gui
  foreach reverse the-entities [add-entity-to-col ?]
  
end



to add-entity-to-col [an-entity ]
  let the-entity last an-entity ;; ok, this naming is shit. we need to fix that at some point
  let the-name name-of the-entity
  let entity-id first an-entity
  
  ;; create a widget for it that has its name
  xw:create-procedure-widget name-of entity-from-id entity-id [
    xw:set-code to-string an-entity 
    xw:set-name the-name
    xw:set-x margin
    xw:set-height 150
    xw:set-width left-column-width
    xw:set-args string:from-list get-args the-entity " "
    xw:set-y margin + sum map [[xw:height] xw:of ?] left-column
    set left-column lput the-name left-column
    xw:set-save-command (word "save-entity-from-widget  \"" the-name "\" " entity-id  " show-it")
    xw:set-delete-command (word "delete-entity " entity-id)
  ]
end

to delete-entity [an-id]
  ;; check if it is being used first
  let entity-name name-of entity-from-id an-id
  let no-of-relationships length relationships-with-entity-id (word an-id)
  if user-yes-or-no? (word entity-name " is in " no-of-relationships " relationships. If you delete it, these relationships will be deleted too")
  [
    ;; delete relationships first 
    foreach map [first ?] relationships-with-entity-id (word an-id)[
      table:remove relationships ?
      draw-center
    ]
    table:remove tasks an-id
  ]
  show-it
end

to-report to-string [an-entity]
  report table:get last an-entity "to-string" 
end




to go
  run-relationships
end

to test
  ;  add-entity "1-sheep-energy" new-entity 1  "sheep with [ an-expression ]" ["an-expression"] "agentset" "-T--"
end

to simulate-eco-ls-system
  setup
  
  
end


to run-relationships
  foreach table:to-list relationships [
    run table:get last ? "task"
  ]
end

to-report make-variadic-task [astring args]
  ;; first turn args into a list, so we can compare full words. (If it's a string, 'test' is a member of 'test2')
  ;  show (list astring  args)
  let arg-no 0
  let sb []
  ;; add spaces so that we can test for hard brackets
  set astring add-spaces astring
  foreach string:rex-split astring " " [
    ifelse member? ? args[
      set sb lput (word "(item " (position ? args) " ?)") sb
    ]
    [
      set sb lput ? sb      
    ]  
  ]
  report string:from-list sb " "
end


to-report new-entity [name model task-string args the-type permitted-contexts]  
  ;  print model
  let task-table table:make
  table:put task-table "name" name
  table:put task-table "model" model
  table:put task-table "to-string" task-string
  if length args > 0 
  [
    set task-string (make-variadic-task task-string args)
  ]
  table:put task-table "args" args
  table:put task-table "type" the-type
  table:put task-table "contexts" permitted-contexts
  ;; special case tasks created in the LevelSpace/Metaverse or whatever stupid name Bryan insists on. <3 <3
  ifelse model = "x"
  [
    table:put task-table "to-task" task [ run-result task-string ]
  ]
  [
    let task-from-model ls:report model (word "task [ " task-string " ]") 
    ;; in terms of knowing how to compile the tasks, we need to know two things:
    ;; first, is it a command or a reporter - this is in the 'the-type' variable
    ;; second, is it runnable from the Observer context. 
    ;; Observer commands/reporters need to be compiled like this:
    ;;;;; task [ls:report model task-string]    
    ;; non-observer ones need to be compiled like thi:
    ;;;;; ls:report model (word "task [ " task-string " ]")  
    ;  show task-from-model task-string
    
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
  ]
  report task-table
end


to-report get-eligible-interactions [an-entity]
  let the-type table:get an-entity "type"
  ;; if it's an observer, they can call observer commands in their own model
  if the-type = "observer"[
    report map [first ?] filter [
      table:get last ? "type" = "command" and 
      member? "O" table:get last ? "contexts" 
    ] 
    table:to-list tasks 
  ]  
  ;; if it's an agentset, they can call turtle commands in their own model or observer commands in other models
  if the-type = "agentset"[
    report map [first ?] filter [
      (table:get last ? "type" = "command" and 
        member? "T" table:get last ? "contexts" and
        table:get last ? "model" = table:get an-entity "model"
        )
      or
      (table:get last ? "type" = "command" and 
        member? "O" table:get last ? "contexts"  and     
        table:get last ? "model" != table:get an-entity "model")
    ] 
    table:to-list tasks 
  ]
  if the-type = "value"[
    report filter [
      table:get last ? "type" = "value"
    ] 
    table:to-list tasks 
  ]  
  user-message (word "Something went wrong getting interactions for " name-of an-entity)
  ;  report 
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
  ;; and breed variables
  add-model-breed-vars the-model
  
  
end

to add-observer [the-model]
  let name (word the-model ":" ls:name-of the-model)
  let the-type "observer"
  ;; observers are different so we just manually create them here 
  let observer-entity table:make
  table:put observer-entity "to-string" name
  table:put observer-entity "model" the-model
  table:put observer-entity "type" the-type
  table:put observer-entity "args" []
  table:put observer-entity "name" name
  add-entity observer-entity
  
end

to add-model-procedures [the-model]
  foreach ls:_model-procedures the-model [
    let procedure-name string:lower-case first ?
    let args map [string:lower-case ?] last ?
    let the-type string:lower-case   item 1 ?
    let args-string ""
    ;; procedures always have postfix argument, so this is easy: 
    repeat length args [set args-string (word args-string " ?")]
    let task-string string:lower-case  (word procedure-name  args-string)
    add-entity new-entity (word the-model "-" procedure-name) the-model task-string args the-type item 2 ?
  ]
end

to add-model-globals [the-model]
  foreach ls:_globals the-model [
    let global-name string:lower-case ?
    let args []
    ;; not sure if these should be reporters (which they technically are) or 'globals' since we probably don't want to SET 
    ;; reporters, but we may want to set globals?
    ;; setting to value now, might not be right though......
    let the-type "value"
    add-entity new-entity (word the-model "-" global-name) the-model global-name args the-type "OTLP"
  ]
end

to add-model-breeds [the-model]
  foreach map [first ?] ls:_list-breeds the-model [
    let agents string:lower-case ?
    let args []
    ;; not sure if these should be reporters (which they technically are) or 'globals' since we probably don't want to SET 
    ;; reporters, but we may want to set globals?
    ;; setting to value now, might not be right though......
    let the-type "agentset"
    add-entity new-entity (word the-model "-" agents) the-model agents args the-type "OTLP"
    
  ]
  ;; finally add patches, links, and turtles 
  foreach (list "patches" "links")[  
    let agents ?
    let args []
    ;; not sure if these should be reporters (which they technically are) or 'globals' since we probably don't want to SET 
    ;; reporters, but we may want to set globals?
    ;; setting to value now, might not be right though......
    let the-type "agentset"
    add-entity new-entity (word the-model "-" agents) the-model agents args the-type "OTLP"
    
  ]  
end




to-report tasks-with [afilter]
  
end

to-report get-ls-task-between [entity1 ent1args entity2 ent2args]
  let first-entity entity entity1 
  let second-entity entity entity2
  let first-entity-type table:get first-entity "type"
  let second-entity-type table:get second-entity "type"
  
  
  if (first-entity-type = "agentset")[
    if second-entity-type = "COMMAND" or second-entity-type = "command" [
      ; if an agenset interacts with a command, each member of the agenset calls the command
      ; this works: let command-task get-task entity "add n co2" let energy-task ls:report 1 "task [energy]" ask run-task "red sheep"[] [let my-energy runresult energy-task (run command-task (list my-energy))]      
      let the-task task[
        let command-task get-task second-entity
        let the-agents (runresult get-task first-entity [])
        ask the-agents [
          (run command-task map [runresult ?] ent2args)
        ]        
      ]
      report the-task 
    ]
  ]
  if first-entity-type = "observer"[
    ;; observers will never have args, so we disregard the first args here
    if second-entity-type = "command" [
      let the-observer-id get-model first-entity
      let the-command get-task second-entity
      let the-task task [
        ;; again here we first resolve the args
        let actual-args2 map [(run-result ? [] )] ent2args
        (run the-command actual-args2)
      ]
      report the-task
    ]
  ]

end
;;; args are a list of tasks ONLY
;to add-ls-interaction-between  [entity1 ent1args entity2 ent2args ent1argstring ent2argstring] ;; string versions are for the gui - they are the names of args, not actuals
;  let first-entity entity entity1 
;  let second-entity entity entity2
;  let first-entity-type table:get first-entity "type"
;  let second-entity-type table:get second-entity "type"
;  
;  
;  if (first-entity-type = "agentset")[
;    if second-entity-type = "COMMAND" or second-entity-type = "command" [
;      ; if an agenset interacts with a command, each member of the agenset calls the command
;      ; this works: let command-task get-task entity "add n co2" let energy-task ls:report 1 "task [energy]" ask run-task "red sheep"[] [let my-energy runresult energy-task (run command-task (list my-energy))]      
;      let the-task task[
;        let command-task get-task second-entity
;        let the-agents (runresult get-task first-entity [])
;        ask the-agents [
;          (run command-task map [runresult ?] ent2args)
;        ]        
;      ]
;      add-relationship the-task entity1 ent1args entity2 ent2args  ent1argstring ent2argstring
;    ]
;  ]
;  if first-entity-type = "observer"[
;    ;; observers will never have args, so we disregard the first args here
;    if second-entity-type = "command" [
;      let the-observer-id get-model first-entity
;      let the-command get-task second-entity
;      let the-task task [
;        ;; again here we first resolve the args
;        let actual-args2 map [(run-result ? [] )] ent2args
;        (run the-command actual-args2)
;      ]
;      add-relationship the-task entity1 ent1args entity2 ent2args ent1argstring ent2argstring
;    ]
;  ]
;end


;; this needs to be rewritten so that it takes an entity and a literal, and then figures out how to turn
;; the literal into a task that takes into account the entity
to-report literal-to-task [an-entity a-literal]
  ;  show (list an-entity a-literal)
  let the-type type-of an-entity
  if the-type = "agentset"[
    let the-task ls:report table:get an-entity "model" (word "task [ "  a-literal " ]")
    report the-task
  ]
  if the-type = "observer" [
    let atask task [ls:report table:get an-entity "model" a-literal]
    report atask
  ]
  ;; if it's neither, something went wrong
  report false
end

to-report entity-name-to-task [entity-name]
  report get-task entity entity-name
end

to-report arg-to-task [arg]
  ;; it's either an entity key, or it's a literal. In the case of the former we get the task
  if member? arg table:keys tasks[
    report get-task table:get tasks arg
  ]
  ;; incase of the latter, we wrap literal arguments in a reporter task here
  if (is-number? arg or is-string? arg or is-list? arg)[
    report task [arg]
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

;; test this and see
to-report entity [entity-name]
  ;  show entity-name
  report last last filter [table:get last ? "name" = entity-name] table:to-list tasks   
end


;;AH: Turn this into a reporter, pass it back, and then decide back in the previous 
to-report add-relationship [atask entity1-name arg1 entity2-name arg2 arg1string arg2string ent1-id ent2-id]
  let relationship-table table:make
  table:put relationship-table "agent-name" entity1-name
  table:put relationship-table "agent-id" ent1-id
  table:put relationship-table "command-name" entity2-name
  table:put relationship-table "command-id" ent2-id
  table:put relationship-table "agent-actuals" arg1
  table:put relationship-table "command-actuals" arg2
  table:put relationship-table "command-arg-names" arg1string
  table:put relationship-table "agent-arg-names" arg2string
  table:put relationship-table "task" atask
  report relationship-table
end

to add-entity [atask-table]
  table:put tasks entity-serial atask-table
  set entity-serial entity-serial + 1
end

to-report all-agent-entities
  report filter [table:get last ? "type" = "agentset" or table:get last ? "type" = "observer"] table:to-list tasks 
end

to-report all-observers
  report filter [table:get last ? "type" = "observer"] table:to-list tasks 
end

to-report model-entities [model-id]
  report filter [table:get last ? "model" = model-id] table:to-list tasks 
end


to-report get-from-model-all-types [model-id a-type]
  report filter [table:get last ? "type" = a-type  and table:get last ? "model" = model-id ] table:to-list tasks
end


;; I think arguments are always any reporter, right?
;; Turns out, no: eligible arguments are:
;;; for agentsets: 
;;;;; their own values (as entities)
;;;;; globals in their own model
;;;; for observers
;;;;;; all global entities
;;;;;; their own globals
;; 
to-report  get-eligible-arguments [an-entity]
  let the-entity-type type-of an-entity
  if the-entity-type = "agentset"[
    report filter [ 
      ;;;;; their own values (as entities) + globals
      (table:get last ? "type" = "reporter" or table:get last ? "type" = "value" ) and 
      (member? "T" table:get last ? "contexts" or member? "O" table:get last ? "contexts" )
      and table:get last ? "model" = table:get an-entity "model"
      
    ] table:to-list tasks
  ]
  if the-entity-type = "observer"[
    
  ]
  report filter [table:get last ? "type" = "reporter" or table:get last ? "type" = "value" ] table:to-list tasks 
end

to-report agent-names
  report map [first ?] all-agent-entities
end

;; I'm not sure how (or even if) this deals with patches and links. Only turtles so far
to add-model-breed-vars  [a-model]
  foreach ls:_list-breeds a-model [
    let the-breed first ?
    let the-vars last ?
    foreach the-vars [
      let entity-name (word ? " (" the-breed ")" )
      let entity-type "reporter"
      let entity-otpl "-T--"
      ;      let the-task task [runresult ?]
      let the-string ?
      let args []
      add-entity new-entity entity-name a-model the-string args entity-type entity-otpl
    ]
  ]
end

to-report get-args [an-entity]
  ;  print an-entity
  report table:get an-entity "args"
end




to-report get-actuals [entity-name caller-entity]
  let the-entity entity entity-name
  let entity-args get-args the-entity
  let entity-actuals []
  foreach entity-args [
    let entity-or-literal user-one-of (word "Do you want the value of " ? " to be an entity or a literal?") ["entity" "literal"]
    if entity-or-literal  = "literal" [
      ;; take it, turn it into a task, put it in actuals
      let the-user-input user-input (word "Please write the value of " ? " here. Use quotation marks for strings.") 
      ;; get the args from the context of the caller
      let the-task literal-to-task entity caller-entity the-user-input 
      set entity-actuals lput the-task entity-actuals 
    ]
    if entity-or-literal = "entity" [
      let eligible-arguments map [first ?] get-eligible-arguments caller-entity
      let the-argument-name user-one-of "Which entity should be its argument?" eligible-arguments
      let the-task get-task entity the-argument-name
      set entity-actuals lput the-task entity-actuals
      ;      set entity-actuals lput entity-to-task first user-one-of (word "Which entity should be its argument?") get-eligible-arguments the-entity entity-actuals 
    ]
  ]
  report entity-actuals
end

to gui-add-entity
  let entity-model user-one-of "In which model do you want to create an entity?" map [first ? ] all-observers
  let entity-type user-one-of "What kind of entity do you want to create?" ["agentset" "value" "command"]
  let entity-name user-input "What do you want to call your entity?" 
  let entity-string user-input "What should it do?"
  let entity-args user-input "If it has any arguments, please write them here, separated by a space. Otherwise leave blank."
  ifelse entity-args != "" [
    set entity-args string:rex-split entity-args  " "
  ]
  [
    set entity-args []
  ]
  let entity-otpl ""
  ;; we need to resolve OTPL here. If it is an agentset, it is accessible to all observers, so that's just "O---"
  if entity-type = "agentset"
  [
    set entity-otpl "O---"
  ]
  ;; I think we always call them 
  set entity-otpl "O---"
  
  let model-id table:get (table:get tasks entity-model) "model"
  add-entity new-entity entity-name model-id entity-string entity-args entity-type "OTPL"
end



to update-output
  clear-output
  foreach table:keys tasks [
    let the-entity entity ?
  ]
end


to-report add-spaces [astring]
  let sb []
  foreach string:to-list astring [
    ifelse ? = "[" or ? = "]"[
      set sb lput (word " " ? " " ) sb
    ]
    [
      set sb lput ? sb
    ] 
  ]
  report string:from-list sb ""
end


to show-model-entities-of-type [amodel a-type]
  clear-output
  output-print (word "Model " amodel " has the following " a-type "s:\n")
  foreach model-entities amodel [
    if table:get last ? "type" = a-type [
      output-print (word first ? ", arguments: " table:get last ? "args")
    ]
  ]
end

to show-relationships
  clear-output
  foreach table:keys relationships  [
    output-print table:get relationships ?
  ]
end

to-report type-of [an-entity]
  report table:get an-entity "type"
end


to-report run-task [the-entity actuals]
  let the-task get-task the-entity
  if (is-reporter-task? the-task)
  [
    report (runresult the-task actuals)
  ]
  if is-command-task? the-task [
    (run the-task actuals)
  ]
end


to do-task [entity-name actuals]
  
  let the-entity entity entity-name
  let the-task get-task the-entity
  (run the-task actuals)
end

to test-a-var [avar]
  
end

to reset-gui
  foreach xw:widgets [xw:remove ?]
  set center-column []
  set left-column []
  draw-gui
end

to clear-gui
  clear-left
  clear-center
end

to clear-center
  foreach butfirst center-column [
    xw:remove ?
    set center-column remove ? center-column
  ]
end

to clear-left
  foreach (sublist left-column 2 length left-column ) [
    set left-column remove ? left-column
    xw:remove ?
  ]
end

to-report get-by-serial
  
end


to save-entity-from-widget [a-widget-name entity-id]
  let the-name [xw:name] xw:of a-widget-name
  ;; first we check if it already exists
  ;; if it doesn't, we just add a new one
  ifelse entity-id = "new"[
    new-entity-from-widget a-widget-name 
  ]
  [
    existing-entity-from-widget a-widget-name entity-id
  ]
  
  
end

to existing-entity-from-widget [a-widget-name entity-id]
  let model-id get-model entity xw:get "Models"
  let name [xw:name] xw:of a-widget-name
  let code [xw:code] xw:of a-widget-name
  ;; turn args into a list of args, not just one long string
  let args-string string:trim [xw:args] xw:of a-widget-name
  let args-list ifelse-value (length args-string = 0) [[]] [string:rex-split args-string " " ]
  ;; @todo: we need a dropdown for this
  
  let the-type current-type
    
  let the-entity 0
  let code-worked? true
  carefully [
    set the-entity new-entity name model-id code args-list the-type "OTPL"
  ]
  [
    set code-worked? false
    show (word code " did not compile correctly")
  ]  
  if code-worked?
  [
    table:put tasks entity-id the-entity
  ]
end

to new-entity-from-widget [a-widget-name]
  let model-id get-model entity xw:get "Models"
  let name [xw:name] xw:of a-widget-name
  let code [xw:code] xw:of a-widget-name
  ;; turn args into a list of args, not just one long string
  let args-string string:trim [xw:args] xw:of a-widget-name
  let args-list ifelse-value (length args-string = 0) [[]] [string:rex-split args-string " " ]
  let the-type current-type
  let the-entity 0
  let code-worked? true
  carefully [
    set the-entity new-entity name model-id code args-list the-type "OTPL"
  ]
  [
    set code-worked? false
    show (word code " did not compile correctly")
  ]
  if code-worked?
  [  
    add-entity the-entity
  ]
end


to-report is-task-right-type? [a-task]
  if xw:get "data-types" = "Commands"[
    ifelse is-command-task? a-task[
      report true
    ]
    [
      report false
    ]
  ]
  if xw:get "data-types" = "Reporters"[
    ifelse is-reporter-task? a-task [
      report true
    ]
    [
      report false
    ]
  ]
  if xw:get "data-types" = "Extended Agents"[
    ifelse is-agentset? run-result a-task [
      report true
    ]
    [
      report false
    ]
  ]
end

to-report entity-from-id [an-id]
  report table:get tasks an-id
end

to-report name-of [a-table]
  report table:get a-table "name"
end

to gui-delete-by-id [  ]
  
end

to-report all-model-entities [model-id]
  report filter [table:get last ? "model" = model-id] table:to-list tasks 
end

to close-and-remove [model-id]
  ls:close model-id
  foreach map [first ?] all-model-entities model-id [
    table:remove tasks ?
  ]
end

to-report current-type
  let widget-type xw:get "data-types"
  if widget-type = "Extended Agents" [report "agentset"]
  if widget-type = "Commands" [report "command"]
  if widget-type = "Reporters" [report "reporter"]
end

to run-relationship-by-id [id]
  let the-relationship-table table:get relationships id
  run table:get the-relationship-table "task"
end

to run-setup-relationship-by-id [id]
  let the-relationship-table table:get setup-relationships id
  run table:get the-relationship-table "task"
end

to-report entity-ids-in-relationships
  report reduce sentence map [(sentence (list run-result table:get last ? "command-id" run-result table:get last ? "agent-id"))] table:to-list relationships 
end

to-report relationships-with-entity-id [an-id]
  report filter [table:get last ? "agent-id" = an-id or table:get last ? "command-id" = an-id] table:to-list relationships
end


to run-relationships-once
  let the-relationships ifelse-value (xw:get "setup-or-go" = "Go") [relationships][setup-relationships]
  foreach table:to-list the-relationships[
      xw:ask (word first ?) [
        xw:set-color yellow 
        run table:get last ? "task"
        xw:set-color cyan]
  ]
end

to move-up [a-relationship-id ]
  let the-relationships ifelse-value (xw:get "setup-or-go" = "Go") [relationships][setup-relationships]
  let relationship-keys map [first ?] table:to-list the-relationships
  ;; find out where in the list it is
  let initial-position position a-relationship-id relationship-keys
  ;; do something only if it's not already first
  if initial-position > 0  [
    ;; create three sublists. One containing everything before the two numbesr being swappe.d
    let list1 sublist relationship-keys 0 (initial-position - 1)
    ;; one containing the two numbers
    let list2 sublist relationship-keys (initial-position - 1) (initial-position + 1)
    set list2 reverse list2
    ;; and one containing everything after them.
    let list3 sublist relationship-keys (initial-position + 1) (length relationship-keys)
    ;; and put them all togetehr again
    let new-ordered-key reduce sentence (list list1 list2 list3)
    ;; now construct a new table using these keys
    let reordered table:make
    foreach new-ordered-key [
      let the-entry table:get the-relationships ?
      table:put reordered ? the-entry
    ]
    ifelse xw:get "setup-or-go" = "Go"
    [
      set relationships reordered
    ]
    [
      set setup-relationships reordered
    ]
  ]
end

to move-down [a-relationship-id]
    let the-relationships ifelse-value (xw:get "setup-or-go" = "Go") [relationships][setup-relationships]
  let relationship-keys map [first ?] table:to-list the-relationships
  ;; find out where in the list it is
  let initial-position position a-relationship-id relationship-keys
  ;; do something only if it's not already first
  if initial-position < (length relationship-keys + 1)  [
    ;; create three sublists. One containing everything before the two numbesr being swappe.d
    let list1 sublist relationship-keys 0 (initial-position)
    ;; one containing the two numbers
    let list2 sublist relationship-keys (initial-position) (initial-position + 2)
    set list2 reverse list2
    ;; and one containing everything after them.
    let list3 sublist relationship-keys (initial-position + 1) (length relationship-keys)
    ;; and put them all togetehr again
    let new-ordered-key reduce sentence (list list1 list2 list3)
    ;; now construct a new table using these keys
    let reordered table:make
    foreach new-ordered-key [
      let the-entry table:get the-relationships ?
      table:put reordered ? the-entry
    ]
    ifelse xw:get "setup-or-go" = "Go"
    [
      set relationships reordered
    ]
    [
      set setup-relationships reordered
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
455
236
7
7
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
-7
7
-7
7
0
0
1
ticks
30.0

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

BUTTON
12
123
140
156
Create an entity
gui-add-entity
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
52
337
192
370
Run relationships
run-relationships
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
NetLogo 5.2.0
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
1
@#$#@#$#@
