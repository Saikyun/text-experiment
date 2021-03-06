(use jaylib)
(import ./text_rendering :prefix "")
(import ./find_row_etc :prefix "")

(varfn dump-state
  [path props]
  (let [props (table/clone props)
        f (file/open path :w)]
    (put props :conf (table ;(reduce array/concat @[] (pairs (props :conf)))))
    (put props :conf nil)
    (put props :data nil)
    (put props :context nil)
    (put props :binds nil)
    
    (try
      (file/write f (marshal props))
      ([err fib]
        (print "Tried to dump:")
        (pp (string/format "%.5m" props))))
    (file/flush f)
    (file/close f)))

(varfn load-state
  [path]
  (let [f (file/open path :r)
        content (file/read f :all)
        res (unmarshal content)]
    (file/close f)
    res))

(comment
  (def text-data @{:selected @""
                   :text @""
                   :after @""
                   :dir nil
                   :scroll 0
                   
                   :position [5 5]
                   :w 590
                   :offset 10
                   
                   :caret-pos [0 0]
                   :blink 0})
  
  (dump-state "text_experiment_dump2" text-data)
  
  (merge-into text-data (load-state "text_experiment_dump"))

  (merge-into text-data (load-state "dddump"))
  
  text-data
  )

(varfn replace-content
  "Delete current content and loads new content."
  [props new]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (buffer/clear text)
  (buffer/clear selected)
  (buffer/clear after)
  (buffer/push-string after (string/reverse new)))

(varfn content
  "Returns a big string of all the pieces in the text data."
  [{:selected selected :text text :after after}]
  (string text selected (string/reverse after)))

(varfn select-until-beginning
  "Selects all text from cursor to beginning of buffer."
  [props]
  (def {:selected selected :text text} props)
  (put props :dir :left)
  (buffer/push-string selected text)
  (buffer/clear text)
  (refresh-caret-pos props))

(varfn select-until-end
  "Selects all text from cursor to end of buffer."
  [props]
  (def {:selected selected :text text :after after} props)
  (put text :dir :right)
  (buffer/push-string selected (string/reverse after))
  (buffer/clear after)
  
  (refresh-caret-pos props))

(varfn select-region
  "Selects text between index start and index end."
  [props start end]
  (let [{:after after :selected selected :text text} props
        both (content props)
        [start end] (if (> start end)
                      (do (put props :dir :left)
                        [end start])
                      (do (put props :dir :right)
                        [start end]))]
    
    (put props :text (buffer/slice both 0 start))
    (put props :selected (buffer/slice both start end))
    
    (buffer/clear after)
    (buffer/push-string after (string/reverse (buffer/slice both end)))
    
    props))

(varfn select-region-append
  "Selects text between index start and index end. If a selection is already active, it appends to that selection."
  [props start end]
  (let [{:after after :selected selected :text text} props
        both (content props)
        
        start (cond (empty? selected)
                start
                
                (= (props :dir) :left)
                (+ (length text) (length selected))
                
                (length text))
        
        [start end] (if (> start end)
                      (do (put props :dir :left)
                        [end start])
                      (do (put props :dir :right)
                        [start end]))]
    
    (put props :text (buffer/slice both 0 start))
    (put props :selected (buffer/slice both start end))
    
    (buffer/clear after)
    (buffer/push-string after (string/reverse (buffer/slice both end)))
    
    props))

(comment
  (def text-data @{:selected @"ghikjlmonp"
                   :text @"abcdef"
                   :after @"qrstuv"
                   :dir nil
                   :scroll 0
                   
                   :position [5 5]
                   :w 590
                   :offset 10
                   
                   :caret-pos [0 0]
                   :blink 0})
  
  (def stuff @{:text (buffer (text-data :text))
               :selected (buffer (text-data :selected))
               :after (buffer (text-data :after))
               :dir (text-data :dir)})
  
  (select-region-append stuff 20 (dec (length (content stuff))))
  
  
  (-> (select-region-append @{:text @"a" :selected @"b" :after @"c" :dir :left} 1 0)
      (get :selected)
      string
      (compare= "ab"))
  #=> true
  
  (-> (select-region-append @{:text @"a" :selected @"b" :after @"c" :dir :left} 1 2)
      (get :selected)
      string
      (compare= ""))
  #=> true
  
  )

(varfn move-to-pos
  "Moves the cursor to position `pos`."
  [props pos]
  (select-region props pos pos))

(varfn select-until-beginning-of-line
  "Selects all text from cursor to beginning of line."
  [props]
  (def {:text text :rows rows :selected selected :current-row current-row} props)
  (def {:start start} (rows current-row))
  
  (select-region-append props (+ (length text) (length selected)) start)
  
  (refresh-caret-pos props))

(varfn move-to-beginning
  "Moves cursor to beginning of buffer."
  [props]
  (def {:selected selected :text text :after after} props)
  (buffer/push-string after (string/reverse selected))
  (buffer/push-string after (string/reverse text))
  (buffer/clear selected)
  (buffer/clear text)
  
  (refresh-caret-pos props))

(varfn move-to-beginning-of-line
  "Moves cursor to beginning of line."
  [props]
  (def {:rows rows :current-row current-row} props)
  (def {:start start} (rows current-row))
  
  (put props :stickiness :down)
  
  (move-to-pos props start)
  
  (refresh-caret-pos props))

(varfn select-until-end-of-line
  "Selects all text from cursor to end of line."
  [props]
  (def {:text text :selected selected :rows rows :current-row current-row} props)
  (def {:stop stop} (rows current-row))
  
  (select-region-append props (length text)
                        (if (= (dec (length rows)) current-row)
                          stop
                          (dec stop)))
  
  (refresh-caret-pos props))

(varfn move-to-end
  "Moves cursor to end of buffer."
  [props]
  (def {:selected selected :text text :after after} props)
  (buffer/push-string text selected)
  (buffer/push-string text (string/reverse after))
  (buffer/clear selected)
  (buffer/clear after)
  
  (refresh-caret-pos props))

(varfn move-to-end-of-line
  "Moves cursor to end of line."
  [props]
  (def {:rows rows :current-row current-row} props)
  (def {:stop stop} (rows current-row))
  
  (let [last-word (last (get-in rows [current-row :words]))]
    (move-to-pos props (if (= last-word "\n")
                         (dec stop)
                         stop)))

  (put props :stickiness :right)
  
  (refresh-caret-pos props))

(varfn copy
  "Copies selected text into clipboard."
  [props]
  (def {:selected selected :text text :after after} props)
  (set-clipboard-text (string selected)))

(varfn delete-selected
  "Deletes selected text.
  Always run when inserting (e.g. writing chars or when pasting).
  Returns previously selected text.
  Returns `nil` if no text was selected."
  [props]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (def old selected)
  (put props :selected @"")
  
  (when (not (empty? old))
    old))

(varfn cut
  "Cuts selected text into clipboard."
  [props]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (set-clipboard-text (string selected))
  (delete-selected props)
  
  (refresh-caret-pos props))

(varfn paste
  "Pastes from clipboard."
  [props]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (delete-selected props)
  (buffer/push-string text (get-clipboard-text))
  
  (refresh-caret-pos props))

(varfn select-surrounding-word
  "Selects the word surrounding the cursor."
  [props]
  (def {:selected selected :text text :after after :dir dir} props)
  (if (= dir :right)
    (buffer/push-string text selected)
    (buffer/push-string after (string/reverse selected)))
  (buffer/clear selected)
  
  (def t-l (first (peg/match '(* (any :S) ($)) (string/reverse text))))
  (def at-l (first (peg/match '(* (any :S) ($)) (string/reverse after))))
  
  (buffer/push-string selected (string/slice text (dec (- t-l))))
  (buffer/push-string selected (string/reverse (string/slice after (dec (- at-l)))))
  (buffer/popn text t-l)
  (buffer/popn after at-l)
  
  (put props :dir :right)
  (refresh-caret-pos props))

(varfn select-all
  "Selects all text in buffer."
  [props]
  (def {:selected selected :text text :after after} props)
  (put props :dir :right)
  (def new-selected (buffer/new (+ (length text)
                                   (length selected)
                                   (length after))))    
  (buffer/push-string new-selected text)    
  (buffer/push-string new-selected selected)    
  (buffer/push-string new-selected (string/reverse after))    
  (put props :selected new-selected)    
  (buffer/clear text)    
  (buffer/clear after)
  (refresh-caret-pos props))

(varfn delete-word-before
  "Deletes the word before the cursor.
  If text is selected deletes the selection instead."
  [props]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (when (not (delete-selected props))
    (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) (string/reverse text)))]
      (buffer/popn text l)))
  (refresh-caret-pos props))

(varfn delete-word-after
  "Deletes the word after the cursor.
  If text is selected deletes the selection instead."
  [props]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (when (not (delete-selected props))
    (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) (string/reverse after)))]
      (buffer/popn after l)))
  (refresh-caret-pos props))

(varfn backspace
  "Deletes a single character before the cursor.
  If text is selected deletes the selection instead."
  [props]
  (def {:selected selected :text text :after after :debug debug} props)
  (when debug (print "backspace!"))
  (if (not (delete-selected props))
    (do (put props :changed [(length text) (dec (length text))])
      (buffer/popn text 1))
    (put props :changed true))
  (refresh-caret-pos props))

(varfn forward-delete
  "Deletes a single character after the cursor.
  If text is selected deletes the selection instead."
  [props]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (when (not (delete-selected props))
    (buffer/popn after 1))
  (refresh-caret-pos props))

(varfn select-word-before
  "Selects a word before the cursor."
  [props]
  (def {:selected selected :text text :after after :dir dir} props)
  (if (and (not (empty? selected))       # when text is selected and the direction is right
           (= dir :right))                  # we deselect rather than select
    (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) (string/reverse selected)))]
      (buffer/push-string after (string/reverse (buffer/slice selected (dec (- l)))))
      (buffer/popn selected l))
    (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) (string/reverse text)))]
      (put props :dir :left)
      (put props :selected (buffer (buffer/slice text (dec (- l))) selected))
      (buffer/popn text l)))
  (refresh-caret-pos props))

(varfn select-word-after
  "Selects a word after the cursor."
  [props]
  (def {:selected selected :text text :after after :dir dir} props)
  (if (and (not (empty? selected))     # when text is selected and the direction is left
           (= dir :left)) # we deselect rather than select
    (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) selected))]
      (buffer/push-string text (buffer/slice selected 0 l))
      (put props :selected (buffer/slice selected l)))
    (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) (string/reverse after)))]
      (put props :dir :right)
      (buffer/push-string selected (string/reverse (buffer/slice after (dec (- l)))))
      (buffer/popn after l)))
  (refresh-caret-pos props))

(varfn move-word-before
  "Moves the cursor one word to the left."
  [props]
  (def {:selected selected :text text :after after} props)
  (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) (string/reverse text)))]
    (when (not (empty? selected))
      (buffer/push-string after (string/reverse selected))
      (buffer/clear selected))
    (buffer/push-string after (string/reverse (buffer/slice text (dec (- l)))))
    (buffer/popn text l))
  (refresh-caret-pos props))

(varfn move-word-after
  "Moves the cursor one word to the right."
  [props]
  (def {:selected selected :text text :after after} props)
  (when-let [l (first (peg/match '(* (any :s) (any :S) ($)) (string/reverse after)))]
    (when (not (empty? selected))
      (buffer/push-string text selected)
      (buffer/clear selected))
    (buffer/push-string text (string/reverse (buffer/slice after (dec (- l)))))
    (buffer/popn after l))
  (refresh-caret-pos props))

(varfn select-char-before
  "Selects the char before the cursor."
  [props]
  (def {:selected selected :text text :after after :dir dir} props)
  (if (and (= dir :right)
           (not (empty? selected)))
    (do (put after (length after) (last selected))
      (buffer/popn selected 1))
    (when (not (empty? text))
      (put props :dir :left)
      (let [o selected]
        (put props :selected (buffer/new (inc (length o))))
        (put (props :selected) 0 (last text))
        (buffer/push-string (props :selected) o))
      (buffer/popn text 1)))
  (refresh-caret-pos props))

(varfn select-char-after
  "Selects the char after the cursor."
  [props]
  (def {:selected selected :text text :after after :dir dir} props)
  (if (and (= dir :left)
           (not (empty? selected)))
    (do (put text (length text) (first selected))
      (put props :selected (buffer/slice selected 1)))
    (when (not (empty? after))
      (put props :dir :right)
      (put selected (length selected) (last after))
      (buffer/popn after 1)))
  (refresh-caret-pos props))

(varfn move-char-before
  "Moves the cursor one char to the left."
  [props]
  (def {:selected selected :text text :after after} props)
  (if (not (empty? selected))
    (do (buffer/push-string after (string/reverse selected))
      (buffer/clear selected))
    (when (not (empty? text))
      (put after (length after) (last text))
      (buffer/popn text 1)))
  (refresh-caret-pos props))

(varfn move-char-after
  "Moves the cursor one char to the right."
  [props]
  (def {:selected selected :text text :after after} props)
  (if (not (empty? selected))
    (do (buffer/push-string text selected)
      (buffer/clear selected))
    (when (not (empty? after))
      (put text (length text) (last after))
      (buffer/popn after 1)))
  
  (put props :stickiness :down)
  
  (refresh-caret-pos props))

(varfn insert-char
  "Inserts a single char."
  [props k]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (case k
    :space (buffer/push-string text " ")
    :grave (buffer/push-string text "`")
    :left-bracket (buffer/push-string text "[")
    :right-bracket (buffer/push-string text "]")
    (do (buffer/clear selected)
      (if (keyword? k)
        (buffer/push-string text (string k))
        (put text (length text) k))))
  (refresh-caret-pos props))

(varfn insert-char-upper
  "Inserts a single uppercase char."
  [props k]
  (def {:selected selected :text text :after after} props)
  (put props :changed true)
  (case k
    :space (buffer/push-string text " ")
    :grave (buffer/push-string text "`")
    :left-bracket (buffer/push-string text "[")
    :right-bracket (buffer/push-string text "]")
    (do (buffer/clear selected)
      (if (keyword? k)
        (buffer/push-string text (string/ascii-upper (string k)))
        (put text (length text) k))))
  (refresh-caret-pos props))

(varfn vertical-move-inner
  [props new-row extreme]
  (def {:caret-pos caret-pos
        :text text
        :full-text full-text
        :sizes sizes
        :positions ps
        :current-row current-row
        :rows rows
        :dir dir
        :position offset}
    props)
  (def [x y] caret-pos)  
  (def [x-offset y-offset] offset)
  
  (reset-blink props)
  
  (def nr (-> (new-row props)
              (min (dec (length rows)))
              (max 0)))
  
  (put props :newest-row nr)
  
  (let [{:start start :stop stop} (rows nr)
        column-i (binary-search-closest (array/slice ps start stop)
                                        |(compare x ($ :center-x)))]
    
    (var pos 0)
    
    (if (= nr current-row)
      (set pos (extreme props))
      (do
        (set pos (+ start column-i))
        (let [newline (= (first "\n") (get full-text (dec pos)))
              wordwrap (and (get-in rows [nr :word-wrapped])
                            (= pos (get-in rows [nr :stop])))]
          
          (cond newline
            (when (< 0 (caret-pos 0))
              (-= pos 1))
            
            wordwrap
            (if (< 0 (caret-pos 0))
              (put props :stickiness :right)
              (put props :stickiness :down))))))
    
    (if (or (key-down? :left-shift)
            (key-down? :right-shift))
      (select-region-append props (cursor-pos props) pos)
      (move-to-pos props pos))
    (put props :caret-pos [(caret-pos 0) ((get-caret-pos props) 1)])
    
    (when (= nr current-row)
      (refresh-caret-pos props)))
  
  props)

(defn vertical-move
  [new-row extreme]
  (fn [props]
    (vertical-move-inner props new-row extreme)))

(varfn previous-row
  [props]
  (max 0 (dec (weighted-row-of-pos props (cursor-pos props)))))

(varfn next-row
  [props]
  (min (dec (length (props :rows)))
       (inc (weighted-row-of-pos props (cursor-pos props)))))

(varfn page-up
  [props]
  
  (let [curr-y (get ((props :rows) (props :current-row)) :y 0)
        new-y (- curr-y (* 0.9 (props :h)))
        row (y->row props new-y)]
    
    (vertical-move-inner props (fn [_] row) (fn [_] 0))))

(varfn page-down
  [props]
  
  (let [curr-y (get ((props :rows) (props :current-row)) :y 0)
        new-y (+ curr-y (* 0.9 (props :h)))
        row (y->row props new-y)]
    
    (vertical-move-inner props (fn [_] row) |(length (content $)))
    (refresh-caret-pos props)))


