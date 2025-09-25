\version "2.22.0"
#(set-global-staff-size 20)

% un-comment the next line to remove Lilypond tagline:
% \header { tagline="" }

% comment out the next line if you're debugging jianpu-ly
% (but best leave it un-commented in production, since
% the point-and-click locations won't go to the user input)
\pointAndClickOff

\paper {
  print-all-headers = ##t %% allow per-score headers

  % un-comment the next line for A5:
  % #(set-default-paper-size "a5" )

  % un-comment the next line for no page numbers:
  % print-page-number = ##f

  % un-comment the next 3 lines for a binding edge:
  % two-sided = ##t
  % inner-margin = 20\mm
  % outer-margin = 10\mm

  % un-comment the next line for a more space-saving header layout:
  % scoreTitleMarkup = \markup { \center-column { \fill-line { \magnify #1.5 { \bold { \fromproperty #'header:dedication } } \magnify #1.5 { \bold { \fromproperty #'header:title } } \fromproperty #'header:composer } \fill-line { \fromproperty #'header:instrument \fromproperty #'header:subtitle \smaller{\fromproperty #'header:subsubtitle } } } }
}

%% 2-dot and 3-dot articulations
#(append! default-script-alist
   (list
    `(two-dots
       . (
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold ":" #})
           (padding . 0.20)
           (avoid-slur . inside)
           (direction . ,UP)))))
#(append! default-script-alist
   (list
    `(three-dots
       . (
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold "⋮" #})
           (padding . 0.30)
           (avoid-slur . inside)
           (direction . ,UP)))))
"two-dots" =
#(make-articulation 'two-dots)

"three-dots" =
#(make-articulation 'three-dots)

\layout {
  \context {
    \Score
    scriptDefinitions = #default-script-alist
  }
}

note-mod =
#(define-music-function
     (text note)
     (markup? ly:music?)
   #{
     \tweak NoteHead.stencil #ly:text-interface::print
     \tweak NoteHead.text
        \markup \lower #0.5 \sans \bold #text
     \tweak Rest.stencil #ly:text-interface::print
     \tweak Rest.text
        \markup \lower #0.5 \sans \bold #text
     #note
   #})
#(define (flip-beams grob)
   (ly:grob-set-property!
    grob 'stencil
    (ly:stencil-translate
     (let* ((stl (ly:grob-property grob 'stencil))
            (centered-stl (ly:stencil-aligned-to stl Y DOWN)))
       (ly:stencil-translate-axis
        (ly:stencil-scale centered-stl 1 -1)
        (* (- (car (ly:stencil-extent stl Y)) (car (ly:stencil-extent centered-stl Y))) 0) Y))
     (cons 0 -0.8))))

%=======================================================
#(define-event-class 'jianpu-grace-curve-event 'span-event)

#(define (add-grob-definition grob-name grob-entry)
   (set! all-grob-descriptions
         (cons ((@@ (lily) completize-grob-entry)
                (cons grob-name grob-entry))
               all-grob-descriptions)))

#(define (jianpu-grace-curve-stencil grob)
   (let* ((elts (ly:grob-object grob 'elements))
          (refp-X (ly:grob-common-refpoint-of-array grob elts X))
          (X-ext (ly:relative-group-extent elts refp-X X))
          (refp-Y (ly:grob-common-refpoint-of-array grob elts Y))
          (Y-ext (ly:relative-group-extent elts refp-Y Y))
          (direction (ly:grob-property grob 'direction RIGHT))
          (x-start (* 0.5 (+ (car X-ext) (cdr X-ext))))
          (y-start (+ (car Y-ext) -0.2))
          (x-start2 (if (eq? direction RIGHT)(+ x-start 0.5)(- x-start 0.5)))
          (x-end (if (eq? direction RIGHT)(+ (cdr X-ext) 0.2)(- (car X-ext) 0.2)))
          (y-end (- y-start 0.5))
          (stil (ly:make-stencil `(path 0.1
                                        (moveto ,x-start ,y-start
                                         curveto ,x-start ,y-end ,x-start ,y-end ,x-start2 ,y-end
                                         lineto ,x-end ,y-end))
                                  X-ext
                                  Y-ext))
          (offset (ly:grob-relative-coordinate grob refp-X X)))
     (ly:stencil-translate-axis stil (- offset) X)))

#(add-grob-definition
  'JianpuGraceCurve
  `(
     (stencil . ,jianpu-grace-curve-stencil)
     (meta . ((class . Spanner)
              (interfaces . ())))))

#(define jianpu-grace-curve-types
   '(
      (JianpuGraceCurveEvent
       . ((description . "Used to signal where curve encompassing music start and stop.")
          (types . (general-music jianpu-grace-curve-event span-event event))
          ))
      ))

#(set!
  jianpu-grace-curve-types
  (map (lambda (x)
         (set-object-property! (car x)
           'music-description
           (cdr (assq 'description (cdr x))))
         (let ((lst (cdr x)))
           (set! lst (assoc-set! lst 'name (car x)))
           (set! lst (assq-remove! lst 'description))
           (hashq-set! music-name-to-property-table (car x) lst)
           (cons (car x) lst)))
    jianpu-grace-curve-types))

#(set! music-descriptions
       (append jianpu-grace-curve-types music-descriptions))

#(set! music-descriptions
       (sort music-descriptions alist<?))


#(define (add-bound-item spanner item)
   (if (null? (ly:spanner-bound spanner LEFT))
       (ly:spanner-set-bound! spanner LEFT item)
       (ly:spanner-set-bound! spanner RIGHT item)))

jianpuGraceCurveEngraver =
#(lambda (context)
   (let ((span '())
         (finished '())
         (current-event '())
         (event-start '())
         (event-stop '()))
     `(
       (listeners
        (jianpu-grace-curve-event .
          ,(lambda (engraver event)
             (if (= START (ly:event-property event 'span-direction))
                 (set! event-start event)
                 (set! event-stop event)))))

       (acknowledgers
        (note-column-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)
                  (add-bound-item span grob)))
             (if (ly:spanner? finished)
                 (begin
                  (ly:pointer-group-interface::add-grob finished 'elements grob)
                  (add-bound-item finished grob)))))
        (inline-accidental-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)))
             (if (ly:spanner? finished)
                 (ly:pointer-group-interface::add-grob finished 'elements grob))))
        (script-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)))
             (if (ly:spanner? finished)
                 (ly:pointer-group-interface::add-grob finished 'elements grob)))))
       
       (process-music .
         ,(lambda (trans)
            (if (ly:stream-event? event-stop)
                (if (null? span)
                    (ly:warning "No start to this curve.")
                    (begin
                     (set! finished span)
                     (ly:engraver-announce-end-grob trans finished event-start)
                     (set! span '())
                     (set! event-stop '()))))
            (if (ly:stream-event? event-start)
                (begin
                 (set! span (ly:engraver-make-grob trans 'JianpuGraceCurve event-start))
                 (set! event-start '())))))
       
       (stop-translation-timestep .
         ,(lambda (trans)
            (if (and (ly:spanner? span)
                     (null? (ly:spanner-bound span LEFT)))
                (ly:spanner-set-bound! span LEFT
                  (ly:context-property context 'currentMusicalColumn)))
            (if (ly:spanner? finished)
                (begin
                 (if (null? (ly:spanner-bound finished RIGHT))
                     (ly:spanner-set-bound! finished RIGHT
                       (ly:context-property context 'currentMusicalColumn)))
                 (set! finished '())
                 (set! event-start '())
                 (set! event-stop '())))))
       
       (finalize
        (lambda (trans)
          (if (ly:spanner? finished)
              (begin
               (if (null? (ly:spanner-bound finished RIGHT))
                   (set! (ly:spanner-bound finished RIGHT)
                         (ly:context-property context 'currentMusicalColumn)))
               (set! finished '())))))
       )))

jianpuGraceCurveStart =
#(make-span-event 'JianpuGraceCurveEvent START)

jianpuGraceCurveEnd =
#(make-span-event 'JianpuGraceCurveEvent STOP)
%===========================================================

%{ The jianpu-ly input was:
title = Temp
composer = Kai
1=bE
7/4
4=69
instrument = 高胡
 2 3b 4# 5 6 7b 1'
4 5 6b 7b 1' 2b' 3
 2 letterA 3b up 4# down 5/// 6 7b 1#' bend 
 \break
4/4
 R2{ 6 \upbow letterB \mf \< - - 5\ Fr=◇ \! ( 6\ \prall  ) } 7b \downbow  \fermata - - - - - - - | 
 2'///\ ^"foo"_"bar" ( 1' ) 7b'. 6\ Fr=> ( 7b\  \mordent )  1'  \turn - - - 
 1=F
 g[d7b] 1' Fr=_ \cresc ( -  1'\ ) 6\ Fr=2 7b\ Fr=内二 ( 1'\ Fr=外 ) | 1' 7 6 Fr=▼ 5 4. 5\ 6\ 1'\ 0 
 R*8 0 0 0 0\\ x\.  
 2 \trill 2  harmonic 8 Fr=x 9 Fr=+
 % 这一行中后面的内容是注释
\pageBreak
 NextPart
 instrument = Erhu
  15 - - - - - 22'  -\ 33'\\\ 44'\\\ 5#5#'\\\  66'\\\
%}


\score {
<< \override Score.BarNumber #'break-visibility = #center-visible
\override Score.BarNumber #'Y-offset = -1
\set Score.barNumberVisibility = #(every-nth-bar-number-visible 5)

%% === BEGIN JIANPU STAFF ===
    \new RhythmicStaff \with {
    \consists "Accidental_engraver" 
    \consists \jianpuGraceCurveEngraver
instrumentName = "高胡"
    % Get rid of the stave but not the barlines:
    \override StaffSymbol #'line-count = #0 % tested in 2.15.40, 2.16.2, 2.18.0, 2.18.2, 2.20.0 and 2.22.2
    \override BarLine #'bar-extent = #'(-2 . 2) % LilyPond 2.18: please make barlines as high as the time signature even though we're on a RhythmicStaff (2.16 and 2.15 don't need this although its presence doesn't hurt; Issue 3685 seems to indicate they'll fix it post-2.18)
    $(add-grace-property 'Voice 'Stem 'direction DOWN)
    $(add-grace-property 'Voice 'Slur 'direction UP)
    $(add-grace-property 'Voice 'Stem 'length-fraction 0.5)
    $(add-grace-property 'Voice 'Beam 'beam-thickness 0.1)
    $(add-grace-property 'Voice 'Beam 'length-fraction 0.3)
    $(add-grace-property 'Voice 'Beam 'after-line-breaking flip-beams)
    $(add-grace-property 'Voice 'Beam 'Y-offset 3.5)
    $(add-grace-property 'Voice 'NoteHead 'Y-offset 3.5)
    }
    { \new Voice="W" {
    \override Beam #'transparent = ##f
    \override Stem #'direction = #DOWN
    \override Tie #'staff-position = #2.5
    \tupletUp
    \tieUp
    \override Stem #'length-fraction = #0.5
    \override Beam #'beam-thickness = #0.1
    \override Beam #'length-fraction = #0.5
    \override Beam.after-line-breaking = #flip-beams
    \override Voice.Rest #'style = #'neomensural % this size tends to line up better (we'll override the appearance anyway)
    \override Accidental #'font-size = #-4
    \override TupletBracket #'bracket-visibility = ##t

    \override Staff.TimeSignature #'style = #'numbered
    \override Staff.Stem #'transparent = ##t
     \mark \markup{1=E\flat} \time 7/4 \tempo 4=69  \note-mod "2" d4  \note-mod "3" \once \tweak Accidental.extra-offset #'(0 . 0.7)ees4
 \note-mod "4" \once \tweak Accidental.extra-offset #'(0 . 0.7)fis4
 \note-mod "5" g4  \note-mod "6" a4  \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes4
 \note-mod "1" c4^. | %{ bar 2: %}
 \note-mod "4" f4
 \note-mod "5" g4  \note-mod "6" \once \tweak Accidental.extra-offset #'(0 . 0.7)aes4
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes4
 \note-mod "1" c4^.  \note-mod "2" \once \tweak Accidental.extra-offset #'(0 . 0.7)des4^.
 \note-mod "3" e4 | %{ bar 3: %}
 \note-mod "2" d4
\mark \markup{ \box { "A" } }  \note-mod "3" \once \tweak Accidental.extra-offset #'(0 . 0.7)ees4
\finger \markup { \fontsize #-4 "↗" }   \note-mod "4" \once \tweak Accidental.extra-offset #'(0 . 0.7)fis4
\finger \markup { \fontsize #-4 "↘" }   \note-mod "5" g4_\tweak outside-staff-priority ##f ^\tweak avoid-slur #'inside _\markup {\with-dimensions #'(0 . 0) #'(2.5 . 2.1) \postscript "1.1 0.4 moveto 2.1 1.4 lineto 1.3 0.2 moveto 2.3 1.2 lineto 1.5 0.0 moveto 2.5 1.0 lineto stroke" } %{ requires Lilypond 2.22+ %} 
 \note-mod "6" a4  \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes4
 \note-mod "1" \once \tweak Accidental.extra-offset #'(0 . 0.7)cis4^.
\finger \markup { \fontsize #-4 "⤻" }  \break \time 4/4 \repeat percent 2 { \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 | %{ bar 4: %}
 \note-mod "6" a4
 ~ \upbow \mark \markup{ \box { "B" } } \mf \< \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" a4
 ~  \note-mod "–" a4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g8[
\finger \markup { \fontsize #-4 "◇" }  \! ( \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a8]
\prall ) } \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 | %{ bar 5: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes4
\=JianpuTie(  ~ \downbow \fermata \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" bes4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" bes4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" bes4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 | %{ bar 6: %}
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes!4 \=JianpuTie)
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" bes4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" bes4
 ~  \note-mod "–" bes4 | | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d8_\tweak outside-staff-priority ##f ^\tweak avoid-slur #'inside _\markup {\with-dimensions #'(0 . 0) #'(2.5 . 2.1) \postscript "1.1 0.4 moveto 2.1 1.4 lineto 1.3 0.2 moveto 2.3 1.2 lineto 1.5 0.0 moveto 2.5 1.0 lineto stroke" } %{ requires Lilypond 2.22+ %} ^.[
]  ^"foo"_"bar" (  \note-mod "1" c4^. )  \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes4.^.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a8[
\finger \markup { \fontsize #-4 ">" }  ( \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes8]
\mordent ) \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 | %{ bar 8: %}
 \note-mod "1" c4^.
 ~ \turn \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" c4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" c4
 ~  \note-mod "–" c4 \mark \markup{1=F} \grace { \jianpuGraceCurveStart s32 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #3
\set stemRightBeamCount = #3
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes32] }
\once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 | %{ bar 9: %}
 \note-mod "1" c4^.
 ~ \finger \markup { \fontsize #-4 "_" }  \cresc (  \note-mod "–" c4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c8^.[
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a8]
\finger \markup { \fontsize #-4 "二" }  \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" \once \tweak Accidental.extra-offset #'(0 . 0.7)bes8[
\finger \markup { \fontsize #-4 "内二" }  ( \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c8^.]
\finger \markup { \fontsize #-4 "外" }  ) | | %{ bar 10: %}
 \note-mod "1" c4^.
 \note-mod "7" b4  \note-mod "6" a4 \finger \markup { \fontsize #-4 "▼" }   \note-mod "5" g4 | %{ bar 11: %}
 \note-mod "4" f4.
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g8[]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c8^.]
 \note-mod "0" r4 \set Score.skipBars = ##t \override MultiMeasureRest #'expand-limit = #1 
R1*8 | %{ bar 12: %}
 \note-mod "0" r4
 \note-mod "0" r4  \note-mod "0" r4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "0" c16[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "x" c8.]
| %{ bar 13: %}
 \note-mod "2" d4
\trill  \note-mod "2" d4 \finger \markup { \fontsize #-4 "○" }   \note-mod "1" c4^. \finger \markup { \fontsize #-4 "x" }   \note-mod "2" d4^. \finger \markup { \fontsize #-4 "+" }  \pageBreak \bar "|." } }
% === END JIANPU STAFF ===


%% === BEGIN JIANPU STAFF ===
    \new RhythmicStaff \with {
    \consists "Accidental_engraver" 
    \consists \jianpuGraceCurveEngraver
instrumentName = "Erhu"
    % Get rid of the stave but not the barlines:
    \override StaffSymbol #'line-count = #0 % tested in 2.15.40, 2.16.2, 2.18.0, 2.18.2, 2.20.0 and 2.22.2
    \override BarLine #'bar-extent = #'(-2 . 2) % LilyPond 2.18: please make barlines as high as the time signature even though we're on a RhythmicStaff (2.16 and 2.15 don't need this although its presence doesn't hurt; Issue 3685 seems to indicate they'll fix it post-2.18)
    $(add-grace-property 'Voice 'Stem 'direction DOWN)
    $(add-grace-property 'Voice 'Slur 'direction UP)
    $(add-grace-property 'Voice 'Stem 'length-fraction 0.5)
    $(add-grace-property 'Voice 'Beam 'beam-thickness 0.1)
    $(add-grace-property 'Voice 'Beam 'length-fraction 0.3)
    $(add-grace-property 'Voice 'Beam 'after-line-breaking flip-beams)
    $(add-grace-property 'Voice 'Beam 'Y-offset 3.5)
    $(add-grace-property 'Voice 'NoteHead 'Y-offset 3.5)
    }
    { \new Voice="X" {
    \override Beam #'transparent = ##f
    \override Stem #'direction = #DOWN
    \override Tie #'staff-position = #2.5
    \tupletUp
    \tieUp
    \override Stem #'length-fraction = #0.5
    \override Beam #'beam-thickness = #0.1
    \override Beam #'length-fraction = #0.5
    \override Beam.after-line-breaking = #flip-beams
    \override Voice.Rest #'style = #'neomensural % this size tends to line up better (we'll override the appearance anyway)
    \override Accidental #'font-size = #-4
    \override TupletBracket #'bracket-visibility = ##t

    \override Staff.TimeSignature #'style = #'numbered
    \override Staff.Stem #'transparent = ##t
     \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 < \note-mod "1" c'  \tweak #'Y-offset #2.0 \note-mod "5" g'  >4
\=JianpuTie(  ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" g'4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" g'4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0  \note-mod "–" g'4
 ~ \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 | %{ bar 2: %}
< \note-mod "1" c'  \tweak #'Y-offset #2.0 \note-mod "5" g'  >4 \=JianpuTie)
 ~  \note-mod "–" g'4 \once \override Tie #'transparent = ##t \once \override Tie #'staff-position = #0 < \note-mod "2" d'  \tweak #'Y-offset #2.0 \note-mod "2" d'' \tweak #'Y-offset #3.6 ^. >4
 ~ \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "–" d''8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #3
< \note-mod "3" e'  \tweak #'Y-offset #2.0 \note-mod "3" e'' \tweak #'Y-offset #3.6 ^. >32
\set stemLeftBeamCount = #3
\set stemRightBeamCount = #3
< \note-mod "4" f'  \tweak #'Y-offset #2.0 \note-mod "4" f'' \tweak #'Y-offset #3.6 ^. >32
\set stemLeftBeamCount = #3
\set stemRightBeamCount = #3
< \note-mod "5" gis'  \tweak #'Y-offset #2.0 \note-mod "5" gis'' \tweak #'Y-offset #3.6 ^. >32
\set stemLeftBeamCount = #3
\set stemRightBeamCount = #3
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "6" a'' \tweak #'Y-offset #3.6 ^. >32] } }
% === END JIANPU STAFF ===

>>
\header{
title="Temp"
composer="Kai"
}
\layout{
  \context {
    \Global
    \grobdescriptions #all-grob-descriptions
  }
} }
\score {
\unfoldRepeats
<< 

% === BEGIN MIDI STAFF ===
    \new Staff { \new Voice="Y" { \transpose c ees { \key c \major  \time 7/4 \tempo 4=69 d'4 ees'4 fis'4 g'4 a'4 bes'4 c''4 | %{ bar 2: %} f'4 g'4 aes'4 bes'4 c''4 des''4 e'4 | %{ bar 3: %} d'4 \mark \markup{ \box { "A" } } ees'4 \finger \markup { \fontsize #-4 "↗" }  fis'4 \finger \markup { \fontsize #-4 "↘" }  g'4:32 a'4 bes'4 cis''4 \finger \markup { \fontsize #-4 "⤻" }  \break \time 4/4 \repeat percent 2 { | %{ bar 4: %} a'4  ~ \upbow \mark \markup{ \box { "B" } } \mf \< a'2 g'8 \finger \markup { \fontsize #-4 "◇" }  \! ( a'8 \prall ) } | %{ bar 5: %} bes'1 \downbow \fermata  ~ | %{ bar 6: %} bes'1 | | %{ bar 7: %} d''8:32 ^"foo"_"bar" ( c''4 ) bes''4. a'8 \finger \markup { \fontsize #-4 ">" }  ( bes'8 \mordent ) | %{ bar 8: %} c''1 \turn } \transpose c f { \key c \major  \grace { bes'32 } | %{ bar 9: %} c''4  ~ \finger \markup { \fontsize #-4 "_" }  \cresc ( c''4 c''8 ) a'8 \finger \markup { \fontsize #-4 "二" }  bes'8 \finger \markup { \fontsize #-4 "内二" }  ( c''8 \finger \markup { \fontsize #-4 "外" }  ) | | %{ bar 10: %} c''4 b'4 a'4 \finger \markup { \fontsize #-4 "▼" }  g'4 | %{ bar 11: %} f'4. g'8 a'8 c''8 r4 \set Score.skipBars = ##t \override MultiMeasureRest #'expand-limit = #1 
R1*8 | %{ bar 12: %} r2. r16 c'8. | %{ bar 13: %} d'4 \trill d'4 \finger \markup { \fontsize #-4 "○" }  c''4 \finger \markup { \fontsize #-4 "x" }  d''4 \finger \markup { \fontsize #-4 "+" }  \pageBreak } } }
% === END MIDI STAFF ===


% === BEGIN MIDI STAFF ===
    \new Staff { \new Voice="Z" { < c' g' >1  ~ | %{ bar 2: %} < c' g' >2 < d' d'' >4  ~ < d' d'' >8 < e' e'' >32 < f' f'' >32 < gis' gis'' >32 < a' a'' >32 } }
% === END MIDI STAFF ===

>>
\header{
title="Temp"
composer="Kai"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
