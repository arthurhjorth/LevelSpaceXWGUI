extensions [ls table string xw cf ]
__includes [ "notebook.nls" ]

breed [models model]
breed [entities-breed entity-breed]
directed-link-breed [relationship-links relationship-link]


to show-models
  foreach all-observers[
    let model-id first ?
    let model-table last ?
    let model-name table:get model-table "name"
    create-models 1 [set label model-name ]
  ]
  layout-circle models 10
end

globals [
  tasks ;; this is a table that contains all custom made tasks (i.e. left hand side stuff)
  relationships ;; this is a table that contains all relationships (i.e. center stuff)
  setup-relationships ;; this is a table that contains all relationships that are run at setup
  test-var
  wsp
  cc
  left-column-width
  center-column-width
  entity-serial
  relationship-serial
  setup-relationships-serial
  base-relationship-height
  static-widget-color
]

to startup
  setup
end

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
  table:put observer-entity "builtin" true
  table:put observer-entity "visible" true
  table:put observer-entity "path" "none"
  add-entity observer-entity
  
  set left-column []
  set left-column-width 400
  set center-column-width 450
  set center-column []
  set base-relationship-height 110
  set static-widget-color blue + 1
  
  set margin 10
  
  setup-notebook
  reset-gui
  file-open ("LevelSpace_logging.txt")
  log-to-file (list "setup run")
  reset-ticks
end

to draw-GUI
  draw-entity-lister
  draw-aux-buttons
  draw-relationship-builder
  draw-center
end

to draw-aux-buttons
  let aux-x (margin * 3) + (left-column-width + center-column-width)
  xw:ask "lsgui" [
    xw:create-button "run-setups" [
      xw:set-label "Run Setup Commands"
      xw:set-commands "run-setup-relationships-once"
      xw:set-x aux-x
      xw:set-y margin
      xw:set-width 200
    ]

    xw:create-button "go-once-button" [
      xw:set-label "Go once"
      xw:set-commands "run-go-relationships-once log-to-file \"go once pressed\""
      xw:set-x aux-x
      xw:set-y margin + 50
      xw:set-width 200
    ]
    
    xw:create-toggle-button "go-forever" [
      xw:set-label "Update commands"
      xw:set-label "Go"
      xw:set-height 50
      xw:set-x aux-x
      xw:on-selected?-change [
        log-to-file (list "go pressed" xw:selected? relationships )
        while [ [ xw:selected? ] xw:of "go-forever"]  [
          run-go-relationships-once
        ]
      ]
      
      xw:set-x aux-x
      xw:set-y margin + 100
      xw:set-width 200
    ]


     xw:create-slider "run-speed" [
      xw:set-color static-widget-color
      xw:set-label "Run Step Delay"
      xw:set-units "ms"
      xw:set-maximum 1000
      xw:set-value 300
      xw:set-increment 100
      xw:set-x aux-x
      xw:set-y margin + 150
      xw:set-width 200
    ]
     
     

    xw:create-button "load-new-model" [
      xw:set-label "Open Model"
      xw:set-commands "load-and-setup-model user-file"
      xw:set-x aux-x
      xw:set-y margin + 200
      xw:set-width 200
    ]

    xw:create-button "save-work" [
      xw:set-label "Save LevelSpace System"
      xw:set-commands "save-to-one-file"
      xw:set-x aux-x
      xw:set-y margin + 250
      xw:set-width 200
    ]
    xw:create-button "load-work" [
      xw:set-label "Load LevelSpace System"
      xw:set-commands "load-from-one-file"
      xw:set-x aux-x
      xw:set-y margin + 300
      xw:set-width 200
    ]
    
  ]
end

;; AH: this isc alled at the wrong times.
to draw-relationship-builder
  
  xw:ask "lsgui" 
  [
    xw:create-chooser "setup-or-go" [
      xw:set-color static-widget-color
      xw:set-label "Show setup or go relationships: " 
      xw:set-items ["Setup" "Go"] 
      xw:set-x margin * 2 + left-column-width
      xw:set-width center-column-width
      ;; only find the height of them all except the last because that is itself
        xw:set-y margin + sum map [[xw:height] xw:of ?] center-column
      set center-column fput "setup-or-go" center-column
      
    ]
    xw:on-change "setup-or-go" [draw-center]
  ]
end

to layout-center
  let y margin
  xw:ask center-column [
    xw:set-y y
    set y y + xw:height
  ]
end

to draw-center
  clear-center
    xw:create-relationship "new-rel" 
    [
      xw:set-color static-widget-color
      xw:set-y margin + sum map [[xw:height] xw:of ?] center-column
      xw:set-width center-column-width
      xw:set-x margin * 2 + left-column-width
      xw:set-available-agent-reporters map [(word table:get last ? "model" ":" name-of last ?)] filter [table:get last ? "visible"] all-agent-entities      
      xw:set-available-procedures []
      xw:set-selected-agent-reporter-index 0
      xw:on-selected-agent-reporter-change [
        update-commands-in-gui "new-rel"
        update-agent-args "new-rel"
        xw:ask "new-rel" [
          xw:set-selected-procedure-arguments []
          xw:set-selected-agentset-arguments []
        ]
        layout-center
      ]
      xw:on-selected-procedure-change [
        update-command-args "new-rel"
        layout-center
      ]
      xw:set-save-command "save-relationship-from-gui \"new-rel\""

      set center-column lput "new-rel" center-column 
      resize-relationship
    ]
    
;    
    ;; list existing relationships; first find out if we're looking at startup or go relationships
    let the-relationships ifelse-value (xw:get "setup-or-go" = "Go") [relationships][setup-relationships]
    foreach table:to-list the-relationships [
      let relationship-id first ?
      let the-entity last ?
      let widget-name (word relationship-id)
      let agent-id table:get the-entity "agent-id"
      let command-id table:get the-entity "command-id"
      xw:create-relationship widget-name [
        xw:set-y margin + sum [xw:height] xw:of center-column
        xw:set-width center-column-width
        set center-column lput (word first ?) center-column            
        xw:set-x margin * 2 + left-column-width
        xw:set-height base-relationship-height
        xw:set-available-agent-reporters map [(word table:get last ? "model" ":" name-of last ?)] all-agent-entities
        
        
        
        
        ;; in order to set the indices, we need to turn our list of tuples of varname->entity-id into a 
        ;; list of tuples of varname->item.
;        let command-arg-id-tuples table:get the-entity "command-arg-id-tuples"


        ;; AH: we find the dropdown index and set it for agents
        xw:set-selected-agent-reporter-index agent-item-from-id agent-id
        ;; we then update the commands and the agent arts
        update-commands-in-gui widget-name
        update-agent-args widget-name
        
        

        let temp-widget-name widget-name
        xw:set-up-command (word "move-up " first ? " draw-center")
        xw:set-down-command (word "move-down " first ? " draw-center")
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
        ;; AH: We are finding the item and then setting the procedure/command entity
        let command-item command-item-from-agent-and-command-id agent-id command-id
        xw:set-selected-procedure-index command-item
        
        ;; set the available command args
        update-command-args temp-widget-name

        ;; and finally set the selected args for both agents and procedures
        ;; at that point we can set the agent arg indices because the agent args are in the dropdowns (        "command-arg-id-tuples")
        let agent-arg-id-tuples table:get the-entity "agent-arg-id-tuples"
        let agent-arg-item-tuples map [(list (first ?) (item-from-entity-and-id entity-from-id table:get the-entity "agent-id" last ?))] agent-arg-id-tuples
        xw:set-selected-agentset-argument-indices agent-arg-item-tuples
              
        let command-arg-id-tuples table:get the-entity "command-arg-id-tuples"
        let command-arg-item-tuples map [(list (first ?) (item-from-entity-and-id entity-from-id table:get the-entity "agent-id" last ?))] command-arg-id-tuples
        xw:set-selected-procedure-argument-indices command-arg-item-tuples
        

      ifelse xw:get "setup-or-go" = "Go"[
        xw:set-delete-command (word "delete-relationship" " " widget-name " draw-center")
        xw:set-run-command (word "run-relationship-by-id " relationship-id)
      ]  
      [
        xw:set-delete-command (word "delete-setup-relationship" " " widget-name " draw-center")        
        xw:set-run-command (word "run-setup-relationship-by-id " relationship-id)
      ]
      
      xw:set-save-command (word "save-relationship-from-gui \"" relationship-id  "\" xw:remove \"" relationship-id  "\" set center-column remove \"" relationship-id  "\" center-column   draw-center")
      ]
    ]
end


;; call this when available-agent-reporters changes.
to update-commands-in-gui [a-relationship-widget]
  xw:ask a-relationship-widget [
    let chosen-agent-entity selected-agent-entity-from-relationship-widget a-relationship-widget
    xw:set-available-procedures map [(word table:get entity-from-id ? "model" ":" name-of entity-from-id ?) ] get-eligible-interactions chosen-agent-entity
  ]
end


to update-command-args [a-relationship-widget]
  xw:ask a-relationship-widget [
    ;; first find agent-id
    let chosen-agent-item [xw:selected-agent-reporter-index] xw:of a-relationship-widget
    ;; Ok, now we have the item. Since this is always the same, it's easy to look this up.
    let acting-entity-id agent-entity-id-from-item chosen-agent-item
    
    ;; then find command-id
    let chosen-command-item [xw:selected-procedure-index] xw:of a-relationship-widget
    ;; then get the from the agent selector
    let chosen-agent selected-agent-entity-from-relationship-widget a-relationship-widget
    ;; so that we can get the command entity-id (because agent disambiguates that)
    let command-entity-id command-entity-id-from-item chosen-agent chosen-command-item
    let args get-arg-tuples-with-deps acting-entity-id command-entity-id
    xw:set-available-procedure-arguments args
    resize-relationship
  ]
end


;;AH: @TODO this (and with command args) is where we need to deal with getting them without the string splitting. It shouldn't be that hard
;; I just need to pass the list of indices or something. Or maybe the entity itself.
to update-agent-args [a-relationship-widget ]
  xw:ask a-relationship-widget [
    let chosen-agent-item [xw:selected-agent-reporter-index] xw:of a-relationship-widget
    ;; Ok, now we have the item. Since this is always the same, it's easy to look this up.
    let acting-entity-id agent-entity-id-from-item chosen-agent-item
    let args get-arg-tuples-with-deps acting-entity-id acting-entity-id
    xw:set-available-agentset-arguments args
    resize-relationship
  ]
end

to resize-relationship
  ;; 29 was determined empirically - bch
  xw:set-height base-relationship-height + 29 * (length xw:available-agentset-arguments + length xw:available-procedure-arguments)
end

to-report get-arg-tuples-with-deps [identity-id-elig identity-id-args ]
  let eligibility-entity entity-from-id identity-id-elig
  let arg-entity entity-from-id identity-id-args
  let the-args get-args arg-entity
  let outer []
  let eligible-args get-eligible-arguments eligibility-entity
  foreach the-args [
    let tuple (list ? map [(word table:get last ? "model"":" table:get last ? "name")] eligible-args)
    set outer lput tuple outer
  ]
  report outer
end


to delete-relationship [a-widget]
  log-to-file (list "deleting go-relationship " a-widget table:get relationships a-widget)
  table:remove relationships a-widget
end

to delete-setup-relationship [a-widget]
  log-to-file (list "deleting setup-relationship " a-widget table:get setup-relationships a-widget)
  table:remove setup-relationships a-widget
end

to save-relationship-from-gui [a-widget]
  ;; find the agent
  let chosen-agent-item [xw:selected-agent-reporter-index] xw:of a-widget
  ;; Ok, now we have the item. Since this is always the same, it's easy to look this up.
  let acting-entity-id agent-entity-id-from-item chosen-agent-item
  let acting-entity entity-from-id acting-entity-id
  let acting-entity-name name-of acting-entity
  
  ; and now do the same for the procedure
  let chosen-command-item [xw:selected-procedure-index] xw:of a-widget
  let command-entity-id command-entity-id-from-item acting-entity chosen-command-item
  let command-entity entity-from-id command-entity-id
  let command-entity-name name-of command-entity
  
  let acting-args get-args acting-entity
  let agent-arg-indices [xw:selected-agentset-argument-indices] xw:of a-widget
  let acting-actuals actuals-from-item-tuples acting-entity agent-arg-indices
  
  let command-args get-args command-entity
  let command-arg-indices [xw:selected-procedure-argument-indices ] xw:of a-widget 
  ; The agent determined which arguments are eligible. BCH 5/6/2015
  let command-actuals actuals-from-item-tuples acting-entity command-arg-indices
  
  ;; and create a relationship (a table with all the info we want )
  let the-relationship add-relationship "N/A" acting-entity-name acting-actuals command-entity-name command-actuals command-args acting-args acting-entity-id command-entity-id
  ;; and now add it to the right place
  let relationship-type xw:get "setup-or-go"  

  ;;AH: instead, we will create a list of args + the ENTITY id (not just their item number). We can do a loookup later.
  let command-arg-id-tuples map [(list first ? (arg-from-entity-and-index acting-entity last ?) )] command-arg-indices
  let agent-arg-id-tuples map [(list first ? (arg-from-entity-and-index acting-entity last ?) )] agent-arg-indices
  
  table:put the-relationship "command-arg-id-tuples" command-arg-id-tuples
  table:put the-relationship "agent-arg-id-tuples" agent-arg-id-tuples
  let the-table ifelse-value (relationship-type = "Go") [relationships] [setup-relationships]
  
  log-to-file (list "saving relationships" (list the-relationship relationship-type a-widget))
  
  ifelse a-widget = "new-rel"[
    let rel-id 1 + max (sentence [-1] (table:keys relationships) (table:keys setup-relationships))
    table:put the-table rel-id the-relationship
  ]
  [
    ;; runresult because a-widget is a string, we want a number
    table:put the-table (runresult a-widget) the-relationship
  ]
  draw-center
end


; AH: ATTENTION BRYAN, this is where we need to deal with wrapping literals in tasks
to-report actuals-from-item-tuples [the-entity list-of-var-item-tuples]
  ;; we get a list of tuples, e.g. [["m" 0] ["n" 0]] ["name" item]. We need to turn that into a list of tasks
  let ids-of-eligible-args map [first ?] get-eligible-arguments the-entity
  let ids-of-actuals []
  foreach list-of-var-item-tuples [
    ;; AH: if (last ?) = -1, it is a literal.
    ;; get the id at the position of the selected item from the dropdown
    let the-actual-id item (last ?) ids-of-eligible-args
    set ids-of-actuals lput the-actual-id ids-of-actuals
  ]
  report map [get-task entity-from-id ?] ids-of-actuals
end




to draw-entity-lister
  xw:ask "lsgui" [
    ;; create the models chooser
    xw:create-chooser "Models" [
      xw:set-color static-widget-color
      xw:set-label "Models" 
      xw:set-items map [name-of entity-from-id ?] map [first ?] all-observers  
      xw:set-width left-column-width
      xw:set-x margin
      xw:set-y margin
;      xw:on-selected-item-change [show-it]
      set left-column lput "Models"  left-column  
    ]
    
    xw:create-chooser "data-types" [
      xw:set-color static-widget-color
      xw:set-label "Show this model's entities of type: " 
      xw:set-items ["Extended Agents" "Reporters" "Commands"] 
      xw:set-selected-item "Extended Agents"
      xw:set-x margin
      xw:set-width left-column-width
      ;; only find the height of them all except the last because that is itself
      xw:set-y margin + sum map [[xw:height] xw:of ?] butlast xw:widgets
      set left-column lput "data-types"  left-column 
    ]
    
    ;; take last letter out to remove pluralization
    let the-type substring xw:get "data-types" 0 (length xw:get "data-types" - 1) 
    ;; add widget for creating new entities:
    xw:create-procedure-widget "new thing" [
      xw:set-name (word "New " the-type)
      xw:set-x margin
      xw:set-height 150
      xw:set-width left-column-width
      xw:set-y margin + sum map [[xw:height] xw:of ?] left-column
      set left-column lput "new thing" left-column
      xw:set-color static-widget-color
      xw:set-save-command (word "save-entity-from-widget \"new thing\" \"new\" ") 
    ]
    
    
  ]
  
  xw:on-change "Models" [show-it]
  xw:on-change "data-types" [show-it xw:ask "new thing" [xw:set-name  (word "New " substring xw:get "data-types" 0 (length xw:get "data-types" - 1))] ]
  
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
  
  
;   add entities to the gui
  foreach reverse the-entities [add-entity-to-col ?]
  
end



to add-entity-to-col [an-entity ]
  let the-entity last an-entity ;; ok, this naming is shit. we need to fix that at some point
  let the-name name-of the-entity
  let entity-id first an-entity
  ;; if it's builtin we just create a display widget for it
  ifelse table:get the-entity "builtin"[
    xw:create-procedure-display-widget name-of entity-from-id entity-id [
;      xw:set-code to-string an-entity 
      xw:set-name the-name
      xw:set-x margin
      xw:set-height 68
      xw:set-color grey
      xw:set-width left-column-width
      xw:set-args string:from-list get-args the-entity " "
      xw:set-y margin + sum map [[xw:height] xw:of ?] left-column
      set left-column lput the-name left-column
      xw:on-visible?-change [
        if table:get the-entity "visible" != xw:visible? [
          table:put the-entity "visible" xw:visible?
          draw-center
        ]
      ]
      xw:set-visible? table:get the-entity "visible"
    ]
  ]
  [
    
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
      xw:set-save-command (word "save-entity-from-widget  \"" the-name "\" " entity-id  "")
      xw:set-delete-command (word "delete-entity " entity-id " true")
    ]
  ]
end

to delete-entity [an-id prompt-user?]
  ;; check if it is being used first
  let entity-name name-of entity-from-id an-id
  let no-of-relationships length relationships-with-entity-id an-id
  if no-of-relationships = 0 or prompt-user? or 
     user-yes-or-no? (word entity-name " is in " no-of-relationships " relationships. If you delete it, these relationships will be deleted too")
  [
    log-to-file (word "deleting entity " (list an-id entity-name table:get tasks an-id))
    ;; delete relationships first
    delete-dependencies an-id
    table:remove tasks an-id
  ]
  show-it
  draw-center
end

to delete-dependencies [ entity-id ]
  foreach map [first ?] relationships-with-entity-id entity-id [
    table:remove relationships ?
  ]
end

to-report to-string [an-entity]
  report table:get last an-entity "to-string" 
end

to run-relationship [ rel-obj ]
  let agent-obj table:get tasks (table:get rel-obj "agent-id")
  let cmd-obj table:get tasks (table:get rel-obj "command-id")
  let cmd-model table:get cmd-obj "model"
  let cmd-args map last table:get rel-obj "command-arg-id-tuples"
  
  let agent-type table:get agent-obj "type"
  let agent-model table:get agent-obj "model"
  let agent-args map last table:get rel-obj "agent-arg-id-tuples"
  let agent-arg-vals eval-args "x" "" agent-args
  
  (cf:match agent-type
    cf:= "observer" [
      let cmd-arg-vals eval-args "x" "" cmd-args
      let code get-code cmd-obj 1
      ifelse agent-model = "x" [
        ;; Kinda gross, but we need to be able to run with task args
        (run (runresult (word "task [" code "]")) cmd-arg-vals)
      ] [        
        (ls:ask cmd-model code cmd-arg-vals)
      ]
    ]
    cf:case [ ? = "agentset" and agent-model = cmd-model ] [
      ;; BCH - Since the arguments may be from other models, and since they may change from
      ;; agent to agent, we have to do this looping ourselves.
      foreach (get-agent-list agent-obj agent-arg-vals) [
        let cmd-arg-vals eval-args agent-model ? cmd-args
        (ls:ask cmd-model (word "ask " ? " [ " (get-code cmd-obj 1) " ]") cmd-arg-vals)
      ]
    ]
    cf:= "agentset" [
      foreach (get-agent-list agent-obj agent-arg-vals) [
        let cmd-arg-vals eval-args agent-model ? cmd-args
        (ls:ask cmd-model (get-code cmd-obj 1) cmd-arg-vals)
      ]
    ]
  )
end

to-report get-agent-list [ agent-obj args ]
  report (ls:report
    (table:get agent-obj "model")
    (word "[(word self)] of " (get-code agent-obj 1))
    args
  )
end

to-report eval-args [agent-model self-string args]
  report map [ eval-raw agent-model self-string table:get tasks ? ] args
end

to-report eval-raw [agent-model self-string obj]
  let model table:get obj "model"
  let code table:get obj "to-string"
  report (cf:cond-value
    cf:case [ model = "x" ] [ runresult code ]
    cf:case [ model = agent-model ] [ (ls:report agent-model (word "[ " code " ] of " self-string)) ]
    cf:else [ ls:report model code ]
  )
end
    
to-report get-code [ obj arg-num ]
  report make-variadic-task (table:get obj "to-string") (table:get obj "args") arg-num
end

;; arg-num is the number that the single argument will be given
to-report make-variadic-task [astring args arg-num]
  ;; first turn args into a list, so we can compare full words. (If it's a string, 'test' is a member of 'test2')
  ;  show (list astring  args)
  let arg-no 0
  let sb []
  ;; add spaces so that we can test for hard brackets
  set astring add-spaces astring
  foreach string:rex-split astring "\\s" [
    ifelse member? ? args[
      set sb lput (word "(item " (position ? args) " ?" arg-num ")") sb
    ]
    [
      set sb lput ? sb      
    ]  
  ]
  report string:from-list sb " "
end


to-report new-entity [name model task-string args the-type permitted-contexts]
  let task-table table:make
  table:put task-table "name" name
  table:put task-table "model" model
  table:put task-table "to-string" task-string
  if length args > 0 [
    set task-string (make-variadic-task task-string args 1)
  ]
  table:put task-table "args" args
  table:put task-table "type" the-type
  table:put task-table "contexts" permitted-contexts
  table:put task-table "visible" true
  table:put task-table "builtin" false
  ;; special case tasks created in the LevelSpace/Metaverse or whatever stupid name Bryan insists on. <3 <3
  ifelse model = "x" [
    table:put task-table "task" task [ run-result task-string ]
  ] [
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
        table:put task-table "task" task [(ls:report model task-string ?)]    
      ]
      ;; turtle reporters here
      [
        table:put task-table "task" ls:report model (word "task [ " task-string " ]")  
      ]
    ]
    ;; or it is a command task\
    [
      ;; observer commands are command tasks that are compiled in the observer of the parent model,
      ifelse member? "O" permitted-contexts[
        table:put task-table "task" task [(ls:ask model task-string ?)]
      ]
      ;; turtle commands here:
      [
        ;; turtle commands are tasks that are compiled in the context of the child model's observer
        table:put task-table "task" ls:report model (word "task [ " task-string " ]")
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
      and table:get last ? "visible"
    ] 
    table:to-list tasks 
  ]  
  ;; if it's an agentset, they can call turtle commands in their own model or observer commands in other models
  if the-type = "agentset"[
    report map [first ?] filter [
      ((table:get last ? "type" = "command" and 
        member? "T" table:get last ? "contexts" and
        table:get last ? "model" = table:get an-entity "model"
        )
      or
      (table:get last ? "type" = "command" and 
        member? "O" table:get last ? "contexts"  and     
        table:get last ? "model" != table:get an-entity "model"))
      and table:get last ? "visible"
    ] 
    table:to-list tasks 
  ]
  if the-type = "value"[
    report filter [
      table:get last ? "type" = "value" and
      table:get last ? "visible"
    ] 
    table:to-list tasks 
  ]  
  user-message (word "Something went wrong getting interactions for " name-of an-entity)
  ;  report 
end



to load-and-setup-model [model-path]
  if is-string? model-path [
    let load-file last string:rex-split model-path "/" 
    print (word "loading: " load-file)

    let the-model 0
    (ls:load-gui-model load-file [set the-model ?])
    ;; add the observer of the model
    add-observer the-model load-file
    ;; add all a models procedures
    add-model-procedures the-model
    ;; and globals
    add-model-globals the-model
    ;; and breeds
    add-model-breeds the-model
    ;; and breed variables
    add-model-breed-vars the-model
    log-to-file (list "model loaded" load-file)
    reset-gui
  ]
end

to add-observer [the-model model-path]
  let name (word the-model ":" ls:name-of the-model)
  let the-type "observer"
  ;; observers are different so we just manually create them here 
  let observer-entity table:make
  table:put observer-entity "to-string" name
  table:put observer-entity "model" the-model
  table:put observer-entity "type" the-type
  table:put observer-entity "args" []
  table:put observer-entity "name" name
  table:put observer-entity "visible" true
  table:put observer-entity "builtin" true
  table:put observer-entity "path" model-path
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
    let the-entity new-entity procedure-name the-model task-string args the-type item 2 ?
    table:put the-entity "visible" true
    table:put the-entity "builtin" true
    add-entity the-entity
  ]
end

to add-model-globals [the-model]
  foreach ls:_globals the-model [
    let global-name string:lower-case ?
    let args []
    ;; not sure if these should be reporters (which they technically are) or 'globals' since we probably don't want to SET 
    ;; reporters, but we may want to set globals?
    ;; setting to value now, might not be right though......
    let the-type "reporter"
    let the-entity new-entity global-name the-model global-name args the-type "OTLP"
    table:put the-entity "builtin" true
    add-entity the-entity
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
    let the-entity new-entity agents the-model agents args the-type "OTLP"
    table:put the-entity "builtin" true
    add-entity the-entity
    
  ]
  ;; finally add patches, links, and turtles 
  foreach (list "patches" "links")[  
    let agents ?
    let args []
    ;; not sure if these should be reporters (which they technically are) or 'globals' since we probably don't want to SET 
    ;; reporters, but we may want to set globals?
    ;; setting to value now, might not be right though......
    let the-type "agentset"
    let the-entity new-entity agents the-model agents args the-type "OTLP"
    table:put the-entity "builtin" true
    add-entity the-entity
    
  ]  
end


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
  report table:get the-entity "task"
end

to-report get-string [the-entity]
  report table:get the-entity "to-string"
end

to-report get-model [the-entity]
  report table:get the-entity "model"
end



;;; test this and see. 
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

;; We use this for loading old stuff to ensure ids match
to add-entity-with-id [atask-table an-id]
  table:put tasks an-id atask-table
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

to-report  get-eligible-arguments [an-entity]
  let observer? table:get an-entity "type" = "observer"
  let model table:get an-entity "model"
  let args filter [
    table:get last ? "type" = "reporter" and
    table:get last ? "args" = [] and
    (not observer? or member? "O" table:get last ? "contexts") and
    (model = table:get last ? "model" or member? "O" table:get last ? "contexts") and
    table:get last ? "visible"
  ] table:to-list tasks
  report args
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
     let the-entity new-entity entity-name a-model the-string args entity-type entity-otpl
     table:put the-entity "builtin" true
      add-entity the-entity
    ]
  ]
end

to-report get-args [an-entity]
  report table:get an-entity "args"
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
    ifelse ? = "[" or ? = "]" or ? = ")" or ? = "(" [
      set sb lput (word " " ? " " ) sb
    ]
    [
      set sb lput ? sb
    ] 
  ]
  report string:from-list sb ""
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

to reset-gui
  foreach xw:widgets [xw:remove ?]
  set center-column []
  set left-column []
  draw-gui
  ;; Stupid timing bugs. Using carefully, it consistently selects the correct tab.
  ;; Without, it complains occasionally about no tab existing. BCH
  carefully [
    xw:select-tab "lsgui"
  ] []
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
  foreach (sublist left-column 3 length left-column ) [
    set left-column remove ? left-column
    xw:remove ?
  ]
end

to save-entity-from-widget [a-widget-name entity-id]
  let the-name [xw:name] xw:of a-widget-name
  ;; first we check if it already exists
  ;; if it doesn't, we just add a new one
  ifelse entity-id = "new"[
    if entity-name-exists-in-model? the-name get-model entity xw:get "Models" [user-message (word "There is already a thing called  " the-name ". Please give it another name.") stop]
    new-entity-from-widget a-widget-name 
  ] [
    existing-entity-from-widget a-widget-name entity-id
  ]
end

;; Reports created entity if it works, otherwise false
to-report create-entity-from-widget [ widget-name ]
  let model-id get-model entity xw:get "Models"
  let name [xw:name] xw:of widget-name
  let code [xw:code] xw:of widget-name
  ;; turn args into a list of args, not just one long string
  let args-string string:trim [xw:args] xw:of widget-name
  let args-list ifelse-value (length args-string = 0) [[]] [string:rex-split args-string " " ]
  ;; @todo: we need a dropdown for this
  
  let the-type current-type
  
;  log-to-file (list "tried creating entity: " (list model-id name code args-string the-type widget-name))
  
  let created-entity false
  carefully [
    set created-entity new-entity name model-id code args-list the-type "OTPL"
  ] [
    xw:ask widget-name [xw:set-color red]
      log-to-file (list "failed creating entity: " (list model-id name code args-string the-type widget-name))
    user-message error-message
    report false
  ]

  log-to-file (list "succeeded creating entity: " (list model-id name code args-string the-type widget-name))

  report created-entity
end

to existing-entity-from-widget [widget-name entity-id]
  let created-entity create-entity-from-widget widget-name
  if created-entity != false [
    let make-entity? true
    let num-rels length relationships-with-entity-id entity-id
    if num-rels > 0 and length table:get created-entity "args" != length table:get (table:get tasks entity-id) "args" [
      let entity-name table:get created-entity "name"
      set make-entity? user-yes-or-no? (word entity-name " is in " num-rels " relationships. If you change its arguments, these relationships will be deleted.")
      if make-entity? [
        delete-dependencies entity-id
      ]
    ]
    if make-entity? [
      log-to-file (list "created entity" created-entity)
      
      table:put tasks entity-id created-entity
      draw-center ;; redraw center to update the new entity in all drop downs
      xw:ask "new thing" [xw:set-code "" xw:set-args ""] ;; reset the new entities widget
      show-it
    ]
  ]
end

to new-entity-from-widget [widget-name]
  let created-entity create-entity-from-widget widget-name
  if created-entity != false [  
    add-entity created-entity
    draw-center ;; redraw center to update the new entity in all drop downs    
    xw:ask "new thing" [xw:set-code "" xw:set-args ""] ;; reset the new entities widget
    show-it
  ]
end


to-report entity-from-id [an-id]
  report table:get tasks an-id
end

to-report name-of [a-table]
  report table:get a-table "name"
end


to-report all-model-entities [model-id]
  report filter [table:get last ? "model" = model-id] table:to-list tasks 
end

to close-and-remove [model-id]
  ls:close model-id
  
  foreach map [first ?] all-model-entities model-id [
    delete-entity ? false
  ]
end

to-report current-type
  report (cf:match-value xw:get "data-types"
    cf:= "Extended Agents" [ "agentset" ]
    cf:= "Commands"        [ "command" ]
    cf:= "Reporters"       [ "reporter" ]
  )
end

to run-relationship-by-id [id]
  log-to-file (list "run-relationship-by-id"  table:get relationships id)
  run-relationship table:get relationships id
end

to run-setup-relationship-by-id [id]
  log-to-file (list "run-setup-relationship-by-id"  table:get setup-relationships id)
  run-relationship table:get setup-relationships id
end

to-report entity-ids-in-relationships
  report reduce sentence map [(sentence (list run-result table:get last ? "command-id" run-result table:get last ? "agent-id"))] table:to-list relationships 
end

to-report relationships-with-entity-id [an-id]
  report filter [table:get last ? "agent-id" = an-id or table:get last ? "command-id" = an-id] table:to-list relationships
end


to run-setup-relationships-once
  log-to-file (list "run-setup-relationships-once")
  run-relationships-once setup-relationships
  reset-ticks
end

to run-go-relationships-once
;  log-to-file (list "run-go-relationships-once")
  run-relationships-once relationships
  tick
end

to run-relationships-once [ the-relationships ]
;  log-to-file (list "run-the-relationships-once" the-relationships)

  let delay (xw:get "run-speed") / 2000
  let still-need-to-delay? false
  if (delay > 0) [ 
    wait delay 
    set still-need-to-delay? true
  ]
  foreach table:to-list the-relationships [
    if member? (word first ?) xw:widgets and delay > 0 [
      xw:ask (word first ?) [
        xw:set-color yellow
        wait delay
        set still-need-to-delay? false
        xw:set-color cyan
      ]
    ]
    if (still-need-to-delay?) [ wait delay ]
    run-relationship last ?
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
  if initial-position < (length relationship-keys) - 1  [
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

to-report agent-entity-id-from-item [item-id]
  ;; first get all the agents
  let agent-entity-ids map [first ? ] all-agent-entities
  report item item-id agent-entity-ids
end

to-report agent-item-from-id [agent-id]
  let agent-entity-ids map [first ? ] all-agent-entities
  report position agent-id agent-entity-ids
 
end

to-report command-entity-id-from-item [chosen-agent item-id]
  ;; this depends on which agent entity is chosen, so first we get eligible commands for that agent
  let command-entity-ids get-eligible-interactions chosen-agent
  report item item-id command-entity-ids
end

to-report command-item-from-agent-and-command-id [chosen-agent item-id]
    let command-entity-ids get-eligible-interactions entity-from-id chosen-agent
    report position item-id command-entity-ids 
end

to-report selected-agent-entity-from-relationship-widget [awidget]
  let chosen-agent-item [xw:selected-agent-reporter-index] xw:of awidget
  ;; Ok, now we have the item. Since this is always the same, it's easy to look this up.
  let acting-entity-id agent-entity-id-from-item chosen-agent-item
  report entity-from-id acting-entity-id
end

to-report arg-from-entity-and-index [an-entity index]
  report item index (map [first ? ] get-eligible-arguments an-entity)
end

to-report item-from-entity-and-id [an-entity id]
    report position id (map [first ? ] get-eligible-arguments an-entity)
end


to write-list [atable afilename]
  file-close-all
  if file-exists? afilename [file-delete afilename]
  file-open afilename
  let print-list []
  foreach table:to-list atable  [
    let the-table last ?
;    table:remove the-table "task" ;; AH: this removes it from the actual table. that doesn't work. we can just ignore it in the saved list
;; so we "clone" it by turning into a list, then into a table, remove it, and then into a list for printing
    let clone-list table:to-list the-table
    let clone-table table:from-list clone-list
;    if member? "task" table:keys clone-table [show "before: " show clone-table table:remove clone-table "task" show "after:" show clone-table]
    table:remove clone-table "task"
    table:remove clone-table "agent-actuals"
    table:remove clone-table "command-actuals"
    set print-list lput (list first ? table:to-list clone-table) print-list
  ]
  file-write print-list
  file-close-all
end


to save-to-one-file 
  file-close-all
  let filename user-input "What do you want to call your LevelSpace System?"
  if file-exists? filename [file-delete filename]
  write-all filename "tasks"
  write-all filename "relationships"
  write-all filename "setup-relationships"
  file-close-all
  file-open "LevelSpace_logging.txt"
  log-to-file (list "everything saved" tasks relationships setup-relationships)
end

to write-all [filename table-name]
  file-close-all
  file-open filename
  let print-list []
  let table runresult table-name
  foreach table:to-list table [
    let entity-table last ?
;    table:remove the-table "task" ;; AH: this removes it from the actual table. that doesn't work. we can just ignore it in the saved list
;; so we "clone" it by turning into a list, then into a table, remove it, and then into a list for printing
    let clone-list table:to-list entity-table
    let clone-table table:from-list clone-list
;    if member? "task" table:keys clone-table [show "before: " show clone-table table:remove clone-table "task" show "after:" show clone-table]
    table:remove clone-table "task"
    table:remove clone-table "agent-actuals"
    table:remove clone-table "command-actuals"
    table:put clone-table "table" table-name
    set print-list lput (list first ? table:to-list clone-table) print-list
  ]
  file-write print-list
  file-close-all
end

to load-from-one-file
  file-close-all
  let load-file user-file 
  setup
  file-open load-file
  while [not file-at-end?][
    let the-input file-read
    foreach the-input [
      wait .01
      ;; as long as we do things in the order they appear in, we won't skip any interdependencies
      let the-id first ?
      let the-task table:from-list last ?
      let the-table-name table:get the-task "table"
      let the-table runresult the-table-name
      if the-table-name = "tasks"[
        let the-type table:get the-task "type"
        if the-type = "observer" and table:get the-task "name" != "LevelSpace" [
          load-model table:get the-task "path" the-id
        ]
        if the-type = "command" or the-type = "agentset" or the-type = "reporter" [
          load-task the-task the-id
        ]      
      ]
      if the-table-name = "relationships" or the-table-name = "setup-relationships"[
         let acting-entity-id table:get the-task "agent-id"
         let acting-entity entity-from-id acting-entity-id
         let command-entity-id table:get the-task "command-id"
         let command-entity entity-from-id command-entity-id
         
         let acting-arg-ids table:get the-task "agent-arg-id-tuples"
         let acting-actuals map [get-task entity-from-id last ?] acting-arg-ids

         let command-arg-ids table:get the-task "command-arg-id-tuples"
         let command-actuals map [get-task entity-from-id last ?] command-arg-ids

;         ;; and create a relationship (a table with all the info we want )
         let the-relationship add-relationship "N/A" (name-of acting-entity) acting-actuals (name-of command-entity) command-actuals (get-args command-entity) (get-args acting-entity) acting-entity-id command-entity-id
         
         table:put the-relationship "command-arg-id-tuples" command-arg-ids
         table:put the-relationship "agent-arg-id-tuples" acting-arg-ids
         table:put the-table the-id the-relationship
      ]
    ]
  ]
   ; set the two serial numbers to the max of whatever the loaded entities are  + 1
   set entity-serial (max map [first ?] table:to-list tasks) + 1
   ;; there may be zero relationships saved. So we need to first check if there are any, and otherwise just report 0
   let relationship-ids reduce sentence (list map [first ?] table:to-list relationships  map [first ?] table:to-list setup-relationships )
   set relationship-serial ifelse-value (length relationship-ids > 0) [max relationship-ids + 1] [0]
   reset-gui
   ;; finally close the input file and open the logging file again
   file-close-all
   file-open "LevelSpace_logging.txt"
end


to load-task [a-table the-id]
  let the-name table:get a-table "name"
  let model-id table:get a-table "model"
  let string table:get a-table "to-string"
  let args table:get a-table "args"
  let the-type table:get a-table "type"
  let contexts table:get a-table "contexts"
  let visible table:get a-table "visible"
  let builtin table:get a-table "builtin"
; to-report new-entity [name model task-string args the-type permitted-contexts]    
  let the-entity new-entity the-name model-id string args the-type contexts
  table:put the-entity "visible" true
  table:put the-entity "builtin" table:get a-table "builtin"
  add-entity-with-id the-entity the-id
end

;; AH: this procedure is only used when we load from a saved file. It is different from load-and-setup-model in that 
;; we don't create any other entities than the observer entity
to load-model [apath the-id]
  let the-model 0
  (ls:load-gui-model apath [set the-model ?])
  let name (word the-model ":" ls:name-of the-model)
  ;; observers are different so we just manually create them here 
  let observer-entity table:make
  table:put observer-entity "to-string" name
  table:put observer-entity "model" the-model
  table:put observer-entity "type" "observer"
  table:put observer-entity "args" []
  table:put observer-entity "name" name
  table:put observer-entity "visible" true
  table:put observer-entity "builtin" true
  table:put observer-entity "path" apath
  add-entity-with-id observer-entity the-id
end

to log-to-file [message]
  file-open "LevelSpace_logging.txt"
  file-write (list date-and-time message)
  file-flush
end

to-report entity-name-exists-in-model? [aname a-model-id]
  ;; if the name already exists in entities, report true
  report member? aname map [table:get ? "name"] filter [table:get ? "model" = a-model-id] map [last ? ] table:to-list tasks
end
@#$#@#$#@
GRAPHICS-WINDOW
775
10
1271
527
13
13
18.0
1
12
1
1
1
0
1
1
1
-13
13
-13
13
0
0
1
ticks
1.0

@#$#@#$#@
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
