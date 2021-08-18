" Vim syntax file
" Language:     F#
" Filenames:    *.fs *.fsi *.fsx
" Maintainers:  Gregor Uhlenheuer <kongo2002@googlemail.com>
"               cannorin <cannorin@users.noreply.github.com>
"
" Note:         This syntax file is a complete rewrite of the original version
"               of fs.vim from Choy Rim <choy.rim@gmail.com> and a slight
"               modified version from Thomas Schank <ThomasSchank@gmail.com>

if version < 600
    syntax clear
elseif exists('b:current_syntax')
    finish
endif

" F# is case sensitive.
syn case match

" reset 'iskeyword' setting
setl isk&vim

" Scripting/preprocessor directives
syn match    fsharpSScript "^\s*#\S\+" transparent contains=fsharpScript,fsharpRegion,fsharpPreCondit

syn match    fsharpScript contained "#"
syn keyword  fsharpScript contained quitlabels warnings directory cd load use
syn keyword  fsharpScript contained install_printer remove_printer requirethread
syn keyword  fsharpScript contained trace untrace untrace_all print_depth
syn keyword  fsharpScript contained print_length define undef if elif else endif
syn keyword  fsharpScript contained line error warning light nowarn
syn keyword  fsharpScript contained I load r time


" comments
syn match    fsharpSingleLineComment "//.*$" contains=fsharpTodo,@Spell
syn region   fsharpDocComment start="///" end="$" contains=fsharpTodo,fsharpXml,@Spell keepend oneline
syn region   fsharpXml matchgroup=fsharpXmlDoc start="<[^>]\+>" end="</[^>]\+>" contained contains=fsharpXml

" Double-backtick identifiers
syn region   fsharpDoubleBacktick start="``" end="``" keepend oneline

" TODO: computation expression


" symbol names

syn region fsharpValueDef transparent matchgroup=fsharpKeyword start="\<let!\?\|use!\?\>" end="=" contains=fsharpValueDefModifier,fsharpValueBinding,fsharpFuncBinding,fsharpGenericVarBinding
syn keyword fsharpValueDefModifier mutable rec inline public private internal contained

syn region fsharpFuncBinding contained transparent matchgroup=fsharpFuncSymbol start="\w\+\%(\s\+\w\|\s*(\)\@=" matchgroup=NONE end="=\@=" contains=fsharpArgParen,fsharpArg,fsharpTypeAnnotation
syn region fsharpValueBinding contained transparent matchgroup=fsharpSymbol start="\w\+\ze\s*[:=,]" matchgroup=NONE end="=\@=" contains=fsharpTypeAnnotation,fsharpMoreBinding
syn region fsharpGenericVarBinding contained transparent matchgroup=fsharpFuncSymbol start="\w\+\ze<" matchgroup=NONE end="=\@=" contains=fsharpTypeArg,fsharpArgParen,fsharpArg,fsharpTypeAnnotation

syn region fsharpTypeAnnotation matchgroup=NONE start=":" end="[=,)}\]|\n]\@=" contains=fsharpTypeName,fsharpTypeVar,fsharpType

syn region fsharpMemberDef transparent matchgroup=fsharpKeyword start="\<member\|override\>" end="=" contains=fsharpValueDefModifier,fsharpFuncBinding,fsharpValueBinding,fsharpGenericVarBinding,fsharpSelfBinding,fsharpTypeAnnotation
syn match  fsharpSelfBinding "\w\+\ze\s*\." contained nextgroup=fsharpSelfBindingDot skipwhite
syn match  fsharpSelfBindingDot "\." contained nextgroup=fsharpFuncBinding,fsharpValueBinding,fsharpGenericVarBinding skipwhite

" TODO: abstract member & val

syn match  fsharpSymbol "\w\+\%(\s*[:=),]\)\@=" contained nextgroup=fsharpMoreBinding skipwhite skipempty
syn match  fsharpMoreBinding "," contained nextgroup=fsharpSymbol,fsharpArgParen skipwhite skipempty

syn region fsharpFun transparent matchgroup=fsharpKeyword start="fun" matchgroup=fsharpFunArrow end="->" contains=fsharpArgParen,fsharpArg

syn region fsharpArgParen contained transparent matchgroup=fsharpEncl start="(" end=")" contains=fsharpArg,fsharpTypeAnnotation
syn match  fsharpArg "?\?\w\+\%(\s*[,:-=)]\|\s\)\@=" contained

" type names

syn keyword  fsharpTypeDefModifier public private internal nextgroup=fsharpName skipwhite skipempty contained
syn region   fsharpTypeDef matchgroup=fsharpTypeDefKeyword start="\<type\>" matchgroup=fsharpKeyword end="=\|with" contains=fsharpTypeDefModifier,fsharpTypeName,fsharpArgParen

syn match    fsharpTypeAssert ":>\|:?>" nextgroup=fsharpTypeName,fsharpTypeVar skipwhite skipempty
syn keyword  fsharpNew new nextgroup=fsharpTypeName skipwhite skipempty

syn region   fsharpTypeArg matchgroup=fsharpEncl start="<" end=">" contains=fsharpTypeName,fsharpTypeVar contained
syn match    fsharpQualifiedType "\." contained nextgroup=fsharpTypeName skipwhite skipempty
syn match    fsharpTypeName "\<\w\+\>" contained nextgroup=fsharpTypeArg,fsharpQualifiedType,fsharpType skipwhite skipempty

syn match    fsharpTypeVar    "'\w\+" nextgroup=fsharpTupleType skipwhite skipempty
syn match    fsharpTypeVar    "\^\w\+" nextgroup=fsharpTupleType skipwhite skipempty

" and names
syn keyword  fsharpAndKeyword  and nextgroup=fsharpAndModifier,fsharpAndSymbol,fsharpAndTypeName skipwhite skipempty
syn keyword  fsharpAndModifier public private internal nextgroup=fsharpAndSymbol,fsharpAndTypeName skipwhite skipempty contained
syn match    fsharpAndSymbol   "\l\w*" contained
syn match    fsharpAndTypeName "\u\w*" contained

" qualified names
syn match    fsharpQualifiedName "\<\&\.\@<!\zs\u\w*\ze\s*\."  nextgroup=fsharpQualifiedDot skipwhite skipempty
syn match    fsharpQualifiedName "\u\w*\ze\s*\." nextgroup=fsharpQualifiedDot skipwhite skipempty contained
syn match    fsharpQualifiedDot "\." nextgroup=fsharpQualifiedName skipwhite skipempty contained

" module names
syn keyword  fsharpOpen       open   nextgroup=fsharpModuleName skipwhite skipempty
syn keyword  fsharpModuleDefKeyword module namespace nextgroup=fsharpModuleModifier,fsharpModuleName skipwhite skipempty
syn keyword  fsharpModuleModifier   rec public private internal nextgroup=fsharpModuleModifier,fsharpModuleName skipwhite skipempty
syn match    fsharpModuleName "\u\w*" contained
syn match    fsharpModuleName "\u\w*\." contained nextgroup=fsharpModuleName skipwhite skipempty

" enclosing delimiters
syn match fsharpEncl "("
syn match fsharpEncl ")"
syn match fsharpEncl "\["
syn match fsharpEncl "\]"
syn match fsharpEncl "{"
syn match fsharpEncl "}"
syn match fsharpEncl "\[|"
syn match fsharpEncl "|\]"
syn match fsharpEncl "{|"
syn match fsharpEncl "|}"

" comments
syn region   fsharpMultiLineComment start="(\*" end="\*)" contains=fsharpTodo
syn keyword  fsharpTodo contained TODO FIXME XXX NOTE

" non-definition keywords
syn keyword fsharpKeyword    as assert base begin class default delegate
syn keyword fsharpKeyword    do done downcast downto elif else end exception
syn keyword fsharpKeyword    extern for function global if in inherit
syn keyword fsharpKeyword    interface lazy match
syn keyword fsharpKeyword    of static struct then
syn keyword fsharpKeyword    to upcast void when while with

syn keyword fsharpKeyword    async atomic break checked component const constraint
syn keyword fsharpKeyword    constructor continue decimal eager event external
syn keyword fsharpKeyword    fixed functor include method mixin object parallel
syn keyword fsharpKeyword    process pure return seq tailcall trait

" additional operator keywords (Microsoft.FSharp.Core.Operators)
syn keyword fsharpKeyword    box hash sizeof typeof typedefof unbox ref fst snd
syn keyword fsharpKeyword    stdin stdout stderr id compare incr decr defaultArg
syn keyword fsharpKeyword    exit ignore lock using

" extra operator keywords (Microsoft.FSharp.Core.ExtraTopLevelOperators)
syn keyword fsharpKeyword    array2D dict set

" math operators (Microsoft.FSharp.Core.Operators)
syn keyword fsharpKeyword    abs acos asin atan atan2 ceil cos cosh exp floor log
syn keyword fsharpKeyword    log10 pown round sign sin sinh sqrt tan tanh truncate
syn keyword fsharpKeyword    infinity infinityf nan nanf

syn keyword fsharpOCaml      asr land lor lsl lsr lxor mod sig

syn keyword fsharpLinq   orderBy select where yield

" TODO: match! yield! return!


" exceptions
syn keyword fsharpException  try failwith failwithf finally invalidArg invalidOp raise
syn keyword fsharpException  rethrow nullArg reraise

" constants
syn keyword fsharpConstant   null
syn keyword fsharpBoolean    false true
syn keyword fsharpSourceBuiltin __LINE__ __SOURCE_DIRECTORY__ __SOURCE_FILE__

" types
syn keyword  fsharpType      array bool byte char decimal double enum exn float
syn keyword  fsharpType      float32 int int16 int32 int64 list nativeint
syn keyword  fsharpType      obj option seq sbyte single string uint uint32 uint64
syn keyword  fsharpType      uint16 unativeint unit int8 uint8 bigint

syn keyword  fsharpType      inref outref byref nativeptr

syn keyword fsharpCoreMethod printf printfn sprintf eprintf eprintfn fprintf
syn keyword fsharpCoreMethod fprintfn

" options
syn keyword  fsharpOption    Some None
syn keyword  fsharpResult    Ok Error

" operators
syn keyword fsharpOperator   not or

syn match   fsharpFormat     display "%\(\d\+\$\)\=[-+' #0*]*\(\d*\|\*\|\*\d\+\$\)\(\.\(\d*\|\*\|\*\d\+\$\)\)\=\([hlL]\|ll\)\=\([bscdiuxXoEefFgGMOAat]\|\[\^\=.[^]]*\]\)" contained

syn match    fsharpCharacter    "'\\\d\d\d'\|'\\[\'ntbr]'\|'.'"
syn match    fsharpCharErr      "'\\\d\d'\|'\\\d'"
syn match    fsharpCharErr      "'\\[^\'ntbr]'"
syn region   fsharpString       start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=fsharpFormat
syn region   fsharpString       start=+"""+ skip=+\\\\\|\\"+ end=+"""+ contains=fsharpFormat
syn region   fsharpString       start=+@"+ skip=+""+ end=+"+ contains=fsharpFormat

syn match    fsharpRefAssign    ":="
syn match    fsharpTopStop      ";;"
syn match    fsharpOperator     "\s\+\zs\^\ze\s\+"
syn match    fsharpOperator     "::"

syn match    fsharpLabel        "\<_\>"

syn match    fsharpOperator     "&&"
syn match    fsharpOperator     "<"
syn match    fsharpOperator     ">"
syn match    fsharpOperator     "|>"
syn match    fsharpOperator     "&&&"
syn match    fsharpOperator     "|||"
syn match    fsharpOperator     "\.\."

syn match    fsharpKeyChar      "|[^\]}]"
syn match    fsharpKeyChar      ";"
syn match    fsharpKeyChar      "\~"
syn match    fsharpKeyChar      "?"
syn match    fsharpKeyChar      "\*"
syn match    fsharpKeyChar      "+"
syn match    fsharpKeyChar      "="
syn match    fsharpKeyChar      "(\*)"

syn match    fsharpOperator     "<-"

syn match    fsharpNumber        "\<\d\+"
syn match    fsharpNumber        "\<-\=\d\(_\|\d\)*\(u\|u\?[yslLn]\|UL\)\?\>"
syn match    fsharpNumber        "\<-\=0[x|X]\(\x\|_\)\+\(u\|u\?[yslLn]\|UL\)\?\>"
syn match    fsharpNumber        "\<-\=0[o|O]\(\o\|_\)\+\(u\|u\?[yslLn]\|UL\)\?\>"
syn match    fsharpNumber        "\<-\=0[b|B]\([01]\|_\)\+\(u\|u\?[yslLn]\|UL\)\?\>"
syn match    fsharpFloat         "\<-\=\d\(_\|\d\)*\.\(_\|\d\)*\([eE][-+]\=\d\(_\|\d\)*\)\=\>"
syn match    fsharpFloat         "\<-\=\d\(_\|\d\)*\.\(_\|\d\)*\([eE][-+]\=\d\(_\|\d\)*\)\=\>"
syn match    fsharpFloat         "\<\d\+\.\d*"

" attributes
syn region   fsharpAttrib matchgroup=fsharpAttribute start="\[<" end=">]"

" regions
syn region   fsharpRegion matchgroup=fsharpPreCondit start="\%(end\)\@<!region.*$"
            \ end="endregion" fold contains=ALL contained

if version >= 508 || !exists("did_fs_syntax_inits")
    if version < 508
        let did_fs_syntax_inits = 1
        command -nargs=+ HiLink hi link <args>
    else
        command -nargs=+ HiLink hi def link <args>
    endif

    HiLink fsharpBraceErr          Error
    HiLink fsharpBrackErr          Error
    HiLink fsharpParenErr          Error
    HiLink fsharpArrErr            Error
    HiLink fsharpCommentErr        Error

    HiLink fsharpSingleLineComment Comment
    HiLink fsharpMultiLineComment  Comment
    HiLink fsharpDocComment        Comment
    HiLink fsharpXml               Comment
    HiLink fsharpDoubleBacktick    String

    HiLink fsharpOpen              Include
    HiLink fsharpScript            Include
    HiLink fsharpPreCondit         Include

    HiLink fsharpKeyword           Keyword

    HiLink fsharpValueDefKeyword   Keyword
    HiLink fsharpValueDefModifier  Keyword
    HiLink fsharpSymbol            Identifier
    "HiLink fsharpArg               Identifier
    HiLink fsharpFuncSymbol        Function
    
    HiLink fsharpTypeDefKeyword    Keyword
    HiLink fsharpTypeDefModifier   Keyword
    HiLink fsharpType              Type
    HiLink fsharpTypeName          Type
    HiLink fsharpTypeVar           Type
    
    HiLink fsharpAndKeyword        Keyword
    HiLink fsharpAndModifier       Keyword
    HiLink fsharpAndSymbol         Function
    HiLink fsharpAndTypeName       Type

    HiLink fsharpModuleDefKeyword  Keyword
    HiLink fsharpModuleModifier    Keyword
    HiLink fsharpModuleName        Identifier

    HiLink fsharpQualifiedName     Type
    
    HiLink fsharpCoreMethod        Keyword
    HiLink fsharpNew               Keyword

    HiLink fsharpOCaml             Statement
    HiLink fsharpLinq              Statement

    HiLink fsharpFunArrow          Keyword
    HiLink fsharpRefAssign         Operator
    HiLink fsharpTopStop           Operator
    HiLink fsharpKeyChar           Operator
    HiLink fsharpOperator          Operator

    HiLink fsharpBoolean           Boolean
    HiLink fsharpConstant          Constant
    HiLink fsharpSourceBuiltin     Constant
    HiLink fsharpCharacter         Character
    HiLink fsharpNumber            Number
    HiLink fsharpFloat             Float

    HiLink fsharpString            String
    HiLink fsharpFormat            Special

    HiLink fsharpException         Exception

    HiLink fsharpLabel             Identifier
    HiLink fsharpOption            Identifier
    HiLink fsharpResult            Identifier

    HiLink fsharpAttrib            Typedef
    HiLink fsharpXmlDoc            Typedef

    HiLink fsharpTodo              Todo

    HiLink fsharpEncl              Delimiter
    HiLink fsharpAttribute         Delimiter

    delcommand HiLink
endif

let b:current_syntax = 'fsharp'

" vim: sw=4 et sts=4
