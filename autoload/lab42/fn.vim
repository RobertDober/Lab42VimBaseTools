"----------------------------------------------------------------------------
" Predefined Fns {{{

function! lab42#fn#nullFn()
endfunction

" Consts {{{{
function! lab42#fn#false(...)
  return 0
endfunction
function! lab42#fn#false_fn()
  return funcref('lab42#fn#false')
endfunction
function! lab42#fn#true(...)
  return 1
endfunction
function! lab42#fn#true_fn()
  return funcref('lab42#fn#true')
endfunction
function! lab42#fn#identity(anything)
  return a:anything
endfunction
function! lab42#fn#id_fn()
  return funcref('lab42#fn#identity')
endfunction
" }}}}
" Ints {{{{
" Operations {{{{{
function! s:adderImpl(...)
  let l:result = 0
  for l:term in copy(a:000)
    let l:result += l:term
  endfor
  return l:result
endfunction

function! lab42#fn#adder()
  if !exists('s:adder')
    let s:adder = function('s:adderImpl')
  endif
  return s:adder
endfunction

function! lab42#fn#inc(...)
  let l:increment = 1
  if a:0 > 0
    let l:increment = a:1
  endif
  return function('s:adderImpl', [l:increment])
endfunction

function! s:multiply(rhs, lhs)
  return a:lhs * a:rhs
endfunction
function! lab42#fn#mult_fn(rhs)
  return funcref('s:multiply', [a:rhs])
endfunction
" Predicates {{{{{
function! lab42#fn#even(n)
  return a:n % 2 == 0
endfunction
function! lab42#fn#even_fn()
  return funcref('lab42#fn#even')
endfunction
function! lab42#fn#odd(n)
  return a:n % 2 == 1
endfunction
function! lab42#fn#odd_fn()
  return funcref('lab42#fn#odd')
endfunction
" }}}}}
" Comparers {{{{{
function! s:less_than(rhs, lhs)
  return a:lhs < a:rhs
endfunction
function! lab42#fn#less_fn(rhs)
  return funcref('s:less_than', [a:rhs])
endfunction
function! s:greater_than(rhs, lhs)
  return a:lhs > a:rhs
endfunction
function! lab42#fn#greater_fn(rhs)
  return funcref('s:greater_than', [a:rhs])
endfunction
" }}}}}
" }}}}
" Strings {{{{
function! s:substituter_prime(str, pat, with, opts)
  return substitute(a:str, a:pat, a:with, a:opts)
endfunction
function! lab42#fn#substituter(pattern, with, ...)
  let l:options = ''
  if a:0 > 0
    let l:options = a:1
  endif
  return lab42#fn#partial_1('s:substituter_prime', '\v' . a:pattern, a:with, l:options)
endfunction
" }}}}
" }}}
" Helpers {{{
" Functional Helpers {{{{
function! lab42#fn#isfn(maybefn)
  return type(a:maybefn) == 2
endfunction
" }}}}

"----------------------------------------------------------------------------
" Dict Helpers {{{{
function! lab42#fn#dict_from_list(list)
  let l:result = {}
  for [l:key, l:val] in a:list
    call extend(l:result, {l:key: l:val})
  endfor
  return l:result
endfunction

function! lab42#fn#get_with_default(dict, key, default)
  if has_key(a:dict, a:key)
    return get(a:dict, a:key)
  else
    if lab42#fn#isfn(a:default)
      return call(a:default, [a:key])
    else
      return a:default
    endif
  endif
endfunction
" }}}
" }}}}

"----------------------------------------------------------------------------
" High Order Functions {{{
" Memoization {{{{

let s:function_memo = {}
function! s:memoize_function(fn)
  let l:repr = string(a:fn)
  let l:memo = s:function_memo[l:repr]
  let l:count = string(l:memo['count'])
  if !has_key(l:memo['values'], l:count)
    let l:memo['values'][l:count] = call(a:fn, [])
  endif
  return l:memo['values'][l:count]
endfunction
function! lab42#fn#memfun(funexp)
  let l:repr     = string(a:funexp)
  if !has_key(s:function_memo, l:repr)
    let s:function_memo[l:repr] = {'count': 0, 'values': {}}
  endif
  let s:function_memo[l:repr]['count'] += 1
  return function('s:memoize_function', [a:funexp])
endfunction
" }}}}

" Some Partial Applications {{{{
function! lab42#fn#partial(funexp, ...)
  return function(a:funexp, copy(a:000))
endfunction

function! s:partial_1_prime(funexp, ...)
  let l:args = copy(a:000)
  let l:first = remove(l:args, -1)
  call insert(l:args, l:first)
  return call(a:funexp, l:args)
endfunction
function! lab42#fn#partial_1(funexp, ...)
  let l:args = copy(a:000)
  call insert(l:args, a:funexp)
  return function('s:partial_1_prime', l:args)
endfunction
" }}}}

" def scan1 {{{{
" scan1 l f acc = foldl l [[], acc] (partial f' f) where
" f' f'' [rl, acc] ele =
"   [add(rl, new), new] where new = (f'' acc ele)
" N.B. We create the closure over f by partial application
function! s:scan1_fprime(funexp, accexp, ele)
  let [l:result, l:acc] = a:accexp
  let l:new             = call(a:funexp, [l:acc, a:ele])

  return [add(l:result, l:new), l:new]
endfunction

function! s:scan1(list, funexp, initial_acc)
  let l:Partial   = function('s:scan1_fprime', [a:funexp])
  let [l:result, _] = lab42#fn#foldl(a:list, [[], a:initial_acc], l:Partial)

  return l:result
endfunction
" }}}}

" def filter {{{{
"filter l f = foldl l [] (partial f' f) where
" f' f'' acc ele = if f'' ele then acc ++ ele else acc end
function! s:filter_prime(funexp, acc, ele)
  if call(a:funexp, [a:ele])
    return add(a:acc, a:ele)
  else
    return a:acc
  endif
endfunction
function! lab42#fn#filter(list, funexp)
  let l:Partial = function('s:filter_prime', [a:funexp])
  return lab42#fn#foldl(a:list, [], l:Partial)
endfunction
" }}}}

" def flatmap {{{{
" flatmap l f = foldl l [] (partial f' f) where
" f' f'' acc ele = acc + fmapped where
" fmapped = if (list (f'' ele)) (f'' ele) else [(f'' ele)]
" }}}}
function! s:flatmap_prime(mapfun, acc, ele)
  let l:map_ele = call(a:mapfun, [a:ele])
  if type(l:map_ele) == 3 " list
    return extend(a:acc, l:map_ele)
  else
    return add(a:acc, l:map_ele)
  endif
endfunction
function! lab42#fn#flatmap(list, funexp)
  return lab42#fn#foldl(a:list, [], function('s:flatmap_prime', [a:funexp]))
endfunction
" def foldl {{{{
function! lab42#fn#foldl(list, acc, funexp)
  let l:result = a:acc
  for l:ele in a:list
    let l:result = call(a:funexp, [l:result, l:ele])
  endfor
  return l:result
endfunction
" }}}}

" def map {{{{
" map l f = foldl l [] (partial f' f) where
" f' f'' acc ele = acc ++ (f'' ele)
" N.B. We create the closure over f by partial application
function! s:map_prime(mapfun, acc, ele)
  let l:newele = call(a:mapfun, [a:ele])
  call add(a:acc, l:newele)
  return a:acc
endfunction
function! lab42#fn#map(list, funexp)
  return lab42#fn#foldl(a:list, [], function('s:map_prime', [a:funexp]))
endfunction
" }}}}

" def map_filter {{{{
function! lab42#fn#map_filter(list, funexp)
  let l:list = copy(a:list)
  let l:mapped = lab42#fn#map(l:list, a:funexp)
  call filter(l:mapped, 'v:val[0]')
  call map(l:mapped, 'v:val[1]')
  return l:mapped
endfunction
" }}}}

"def map_with_index {{{{
" map_with_index xs, f, start:0 inc:1 = foldl xs [[], start] (partial f' inc f) |> head where
" f' inc f [l, i] x = [l ++ ( f x i ), i+inc]
function! s:map_with_index_prime(inc, funexp, acc, ele)
  let [l:l, l:i] = a:acc
  let l:next = call(a:funexp, [a:ele, l:i])
  return [add(l:l, l:next), l:i + a:inc] 
endfunction
function! lab42#fn#map_with_index(list, funexp, ...)
  let l:start = 0
  let l:inc   = 1
  if a:0 > 1
    let l:inc = a:2
  endif
  if a:0 > 0
    let l:start = a:1
  endif
  return lab42#fn#foldl(a:list, [[], l:start], function('s:map_with_index_prime', [l:inc, a:funexp]))[0]
endfunction

" }}}}
" def scan {{{{
function! lab42#fn#scan(list, funexp, ...)
  let l:list = a:list
  if a:0 > 0
    return s:scan1(l:list, a:funexp, a:1)
  elseif empty(l:list)
    return []
  else
    return s:scan1(l:list, a:funexp, l:list[0])
  endif
endfunction " }}}}

" def with_index {{{{
" with_index xs start:0 inc:1 = (foldl xs [[], start] (partial f' inc))[0] where
" f' inc [l, i] x = [l ++ x, i+inc]
function! s:with_index_prime(inc, acc, ele)
  let [l:l, l:i] = a:acc
  return [add(l:l, [a:ele, l:i]), l:i + a:inc] 
endfunction
function! lab42#fn#with_index(list,...)
  let l:start = 0
  let l:inc   = 1
  if a:0 > 1
    let l:inc = a:2
  endif
  if a:0 > 0
    let l:start = a:1
  endif
  return lab42#fn#foldl(a:list, [[], l:start], function('s:with_index_prime', [l:inc]))[0]
endfunction " }}}}

" def zip *lists {{{{
" zip heads &rest = map_with_index heads (partial zip' rest) where
" zip' others ele idx = [ele (map others (partial ele idx))] where
" ele idx list = list[idx]
function! s:ele(idx, list)
  return a:list[a:idx]
endfunction
function! s:zip_prime(others, ele, idx)
  return insert(lab42#fn#map(a:others, function('s:ele', [a:idx])), a:ele)
endfunction
function! lab42#fn#zip(list, ...)
  let l:rest = copy(a:000)
  return lab42#fn#map_with_index(a:list, function('s:zip_prime', [l:rest]))
endfunction " }}}}

" def zip_with {{{{
" zip_with l f = map l (partial f' f) where
" f' f'' ele = [ele, (f'' ele)]
function! s:zip_with_prime(funexp, ele)
  return [a:ele, call(a:funexp, [a:ele])]
endfunction
function! lab42#fn#zip_with(list, funexp)
  return lab42#fn#map(a:list, function('s:zip_with_prime', [a:funexp]))
endfunction
"}}}}
" }}}
