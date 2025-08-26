# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Yechan Lee

#!/usr/bin/env julia
# assign.jl : 그룹 편성 + 문제 배정 + CSV 저장 + 커맨드라인 옵션

using Random

# ========== 유틸 ==========

# 균등 그룹 나누기(섞고 몫/나머지로 분배)
function split_into_groups(students::Vector{T}, n::Int; rng=Random.GLOBAL_RNG) where {T}
    @assert 1 <= n <= length(students) "그룹 수 n은 1 이상, 학생 수 이하이어야 합니다."
    shuffled = copy(students)
    shuffle!(rng, shuffled)
    q, r = divrem(length(shuffled), n)
    groups = Vector{Vector{T}}(undef, n)
    idx = 1
    for i in 1:n
        extra = (i <= r) ? 1 : 0
        groups[i] = shuffled[idx : idx + q + extra - 1]
        idx += q + extra
    end
    return groups
end

# 텍스트 파일에서 한 줄씩 읽어 리스트(빈 줄/공백/ BOM 제거)
function read_list(path::AbstractString)
    lines = readlines(path)
    out = String[]
    for raw in lines
        s = replace(raw, '\ufeff' => "") |> strip
        isempty(s) || push!(out, s)
    end
    return out
end

# CSV용 간단 escape (따옴표 이스케이프하고 전체를 따옴표로 감싸기)
csv_escape(s::AbstractString) = "\"" * replace(s, "\"" => "\"\"") * "\""

# 결과 CSV 저장 (week, group, student, problems)
function save_csv(path::AbstractString,
                  results::Vector{NamedTuple{(:group,:student,:problems),Tuple{Int,String,Vector{String}}}},
                  week::Int)
    open(path, "w") do io
        println(io, "week,group,student,problems")
        for r in results
            probs_joined = join(r.problems, " | ")
            println(io,
                string(week, ",",
                       r.group, ",",
                       csv_escape(r.student), ",",
                       csv_escape(probs_joined)))
        end
    end
    println("CSV 저장 완료: $(path)")
end

# 정수 쿼터 벡터 만들기 (합=total, caps: 각 그룹 최대치)
function make_quotas(total::Int, n::Int;
                     weights::Union{Nothing,AbstractVector{<:Real}}=nothing,
                     caps::Union{Int,AbstractVector{Int}}=typemax(Int))
    @assert total >= 0
    caps_vec = caps isa Int ? fill(caps, n) : collect(caps)
    @assert length(caps_vec) == n
    @assert sum(caps_vec) >= total "caps 합이 total보다 작아 목표 총량을 배분할 수 없습니다."

    q = zeros(Int, n)
    if weights === nothing
        base, r = divrem(total, n)
        q .= base
        for i in 1:r
            q[i] += 1
        end
    else
        @assert length(weights) == n
        wpos = [max(w, 0.0) for w in weights]
        s = sum(wpos)
        @assert s > 0 "weights 합이 0입니다."
        target = [total * (w/s) for w in wpos]
        q .= floor.(Int, target)
        r = total - sum(q)
        rema = [(t - floor(Int,t), i) for (i,t) in enumerate(target)]
        sort!(rema, by = x -> -x[1])
        pos = 1
        while r > 0
            i = rema[pos][2]
            if q[i] < caps_vec[i]
                q[i] += 1
                r -= 1
            end
            pos = (pos == n) ? 1 : pos + 1
        end
    end

    # cap 초과분 회수
    spare = 0
    for i in 1:n
        if q[i] > caps_vec[i]
            spare += q[i] - caps_vec[i]
            q[i] = caps_vec[i]
        end
    end
    # 회수분 재분배
    while spare > 0
        advanced = false
        for i in 1:n
            if q[i] < caps_vec[i]
                q[i] += 1
                spare -= 1
                advanced = true
                spare == 0 && break
            end
        end
        @assert advanced "caps 제약으로 인해 총량을 채울 수 없습니다. 제약을 완화하거나 그룹 수를 늘리세요."
    end

    # 총량 부족 시 보정
    need = total - sum(q)
    while need > 0
        advanced = false
        for i in 1:n
            if q[i] < caps_vec[i]
                q[i] += 1
                need -= 1
                advanced = true
                need == 0 && break
            end
        end
        @assert advanced "caps 제약으로 인해 총량을 채울 수 없습니다. 제약을 완화하거나 그룹 수를 늘리세요."
    end
    return q
end

# ========== 공개 API: 조 편성 전용 ==========

"""
    make_groups(students; n=nothing, size=nothing, seed=nothing, print_output=true)

학생 목록을 섞어 균등하게 조로 나눕니다.
둘 중 하나만 지정하세요:
- `n`: 만들 조 개수 (≥1)
- `size`: 조당 최대 인원(자동으로 필요한 조 개수 계산)

옵션:
- `seed`: 셔플 시드(재현성)
- `print_output`: 콘솔 출력 여부

반환: `Vector{Vector{String}}` (조별 학생 리스트)
"""
function make_groups(students::Vector{String};
                     n::Union{Nothing,Int}=nothing,
                     size::Union{Nothing,Int}=nothing,
                     seed::Union{Nothing,Int}=nothing,
                     print_output::Bool=true)
    @assert !isempty(students) "students가 비어 있습니다."
    if (n === nothing) == (size === nothing)
        error("n(조 개수) 또는 size(조당 최대 인원) 중 하나만 지정하세요.")
    end
    if seed !== nothing
        Random.seed!(seed)
    end
    if n === nothing
        @assert size !== nothing && size > 0 "size는 1 이상의 정수여야 합니다."
        n = ceil(Int, length(students) / size)
    else
        @assert n > 0 "n은 1 이상의 정수여야 합니다."
    end
    @assert n <= length(students) "조 개수 n이 학생 수보다 많을 수 없습니다."

    groups = split_into_groups(students, n)
    if print_output
        for (i, g) in enumerate(groups)
            println("$(i)조 (인원: $(length(g)))")
            println("  ", join(g, ", "))
        end
    end
    return groups
end

# ========== 핵심 1단계: '문항 → 조' (조-중복 금지, copies 배수 지원) ==========

function assign_problems_to_groups_unique(problems::Vector{String},
                                          quotas::Vector{Int};
                                          copies::Int=1,
                                          rng=Random.GLOBAL_RNG)
    k = length(problems)
    n = length(quotas)
    @assert copies >= 1 "copies 는 1 이상의 정수여야 합니다."
    @assert n >= copies "중복 없는 배정을 위해서는 copies ≤ 그룹 수(n) 이어야 합니다."
    @assert sum(quotas) == copies*k "쿼터 합은 정확히 copies*k 이어야 합니다."
    @assert all(q -> q <= k, quotas) "한 조의 최대 유니크 문제 수는 k 입니다(중복 금지 가정)."

    probs = copy(problems)
    shuffle!(rng, probs)

    groups_set = [Set{String}() for _ in 1:n]
    Q_rem = copy(quotas)                         # 남은 쿼터
    used_groups = [Set{Int}() for _ in 1:k]      # 각 문제별 이미 사용한 조

    for pass_idx in 1:copies
        a_t = make_quotas(k, n; weights=Q_rem, caps=Q_rem)  # 이번 패스 할당량(합=k)
        pool = reduce(vcat, [fill(i, a_t[i]) for i in 1:n])
        shuffle!(rng, pool)
        @assert length(pool) == k

        idx = copy(pool)
        for i in 1:k
            if idx[i] in used_groups[i]
                swapped = false
                # 1) 서로 충돌 없는 스왑
                for j in i+1:k
                    if (idx[j] ∉ used_groups[i]) && (idx[i] ∉ used_groups[j])
                        idx[i], idx[j] = idx[j], idx[i]
                        swapped = true
                        break
                    end
                end
                # 2) 내 충돌만 피하는 스왑
                if !swapped
                    for j in i+1:k
                        if idx[j] ∉ used_groups[i]
                            idx[i], idx[j] = idx[j], idx[i]
                            swapped = true
                            break
                        end
                    end
                end
                # 3) 앞쪽까지 확장
                if !swapped
                    for j in 1:i-1
                        if (idx[j] ∉ used_groups[i]) && (idx[i] ∉ used_groups[j])
                            idx[i], idx[j] = idx[j], idx[i]
                            swapped = true
                            break
                        end
                    end
                end
                if !swapped
                    error("충돌 해소 실패: copies를 줄이거나 그룹 수를 늘려주세요.")
                end
            end
            chosen_group = idx[i]
            push!(used_groups[i], chosen_group)
            push!(groups_set[chosen_group], probs[i])
        end

        for g in 1:n
            Q_rem[g] -= a_t[g]
            @assert Q_rem[g] >= 0
        end
    end

    return [collect(s) for s in groups_set]
end

# ========== 2단계: '조 내부 → 학생' (학생-중복 금지, 라운드로빈) ==========

function distribute_to_students_roundrobin(group_probs::Vector{String},
                                           students::Vector{String};
                                           rng=Random.GLOBAL_RNG)
    m = length(students)
    @assert m >= 1 "해당 조에 학생이 없습니다."
    probs = copy(group_probs)
    shuffle!(rng, probs)
    base, r = divrem(length(probs), m)
    counts = [base + (i <= r ? 1 : 0) for i in 1:m]
    assigned = [String[] for _ in 1:m]
    idx = 1
    for i in 1:m
        c = counts[i]
        if c > 0
            append!(assigned[i], @view probs[idx:idx+c-1])
            idx += c
        end
    end
    return assigned
end

# ========== 통합 배정 함수 ==========

function arrange(S::Vector{String}, P::Tuple;
                 n::Union{Nothing,Int}=nothing,
                 copies::Int=1,
                 seed::Union{Nothing,Int}=nothing,
                 quotas_mode::Symbol=:balanced,   # :balanced | :weighted
                 print_output::Bool=true)

    if seed !== nothing
        Random.seed!(seed)
    end
    Week, Problems = P
    k = length(Problems)
    @assert k >= 1 "Problems가 비어 있습니다."

    # 그룹 수 결정
    if n === nothing
        n_ = max(2, Int(floor(sqrt(k))))
        n = min(n_, length(S))
    end
    @assert 2 <= n <= length(S) "그룹 수 n은 최소 2, 최대 학생 수 이하여야 합니다."
    @assert copies >= 1 "copies 는 1 이상의 정수여야 합니다."
    @assert n >= copies "중복 없는 배정을 위해서는 copies ≤ 그룹 수(n) 이어야 합니다."

    # 그룹 생성
    G = split_into_groups(S, n)
    group_sizes = [length(g) for g in G]
    @assert all(sz -> sz >= 1, group_sizes) "빈 그룹이 생겼습니다. n을 줄이세요."

    # 쿼터: 각 조가 받을 총 복제본 수 (합=copies*k), 한 조 최대치는 k(유니크 문제 수)
    total = copies * k
    quotas = if quotas_mode == :weighted
        make_quotas(total, n; weights=group_sizes, caps=k)
    else
        make_quotas(total, n; caps=k)
    end
    @assert sum(quotas) == total

    # 1단계: 조-중복 금지로 유니크 문제 목록 구성
    groups_unique_problems = assign_problems_to_groups_unique(Problems, quotas; copies=copies)

    # 2단계: 조 내부 학생 분배(학생-중복 금지)
    results = NamedTuple{(:group,:student,:problems),Tuple{Int,String,Vector{String}}}[]
    if print_output
        suffix = (copies == 1 ? "" : " (복제배수: ×$(copies))")
        println("$(Week)차 연습문제 배정", suffix)
        println()
    end
    for (gi, students) in enumerate(G)
        probs_unique = groups_unique_problems[gi]
        if print_output
            println("$(gi)조 (인원: $(length(students))) - 배정 문제 수: $(length(probs_unique))")
        end
        per_student = distribute_to_students_roundrobin(probs_unique, students)
        for (si, name) in enumerate(students)
            ps = per_student[si]
            if print_output
                println("  ", name, " - ", join(ps, " / "))
            end
            push!(results, (group=gi, student=name, problems=ps))
        end
        if print_output
            println()
        end
    end
    return results
end

# ========== 간단 CLI 파서 ==========

function print_usage()
    println("""
사용법:
  julia assign.jl --students STUDENTS.txt [그룹 옵션]            # 조만 편성
  julia assign.jl --students STUDENTS.txt --problems PROB.txt --week 3 [배정 옵션] [출력 옵션]

입력 파일:
  - STUDENTS.txt : 학생 이름을 한 줄에 하나씩 (UTF-8)
  - PROB.txt     : 문제 이름을 한 줄에 하나씩 (UTF-8)

그룹 옵션(둘 중 하나, '배정'에서는 둘 다 생략 가능: 자동 결정):
  --groups N          조 개수 지정 (정수)
  --size M            조당 최대 인원 지정 (정수) → 필요 조 수 자동 계산

배정 옵션:
  --week W            주차/회차(정수, CSV 저장 시 기록)
  --copies C          문제 복제 배수(기본 1; 2,3... 가능, 단 C ≤ 그룹 수)
  --weighted          조 인원수 비례로 문제 총량 배분(:weighted). 없으면 균등(:balanced)

출력 옵션:
  --csv PATH          결과를 CSV 파일로 저장(week,group,student,problems)
  --seed SEED         셔플 시드(정수; 재현성)
  --no-print          콘솔 출력 생략

예시:
  # 1) 조만 편성 (조 개수 지정)
  julia assign.jl --students students.txt --groups 4 --seed 42

  # 2) 조만 편성 (조당 최대 인원 지정)
  julia assign.jl --students students.txt --size 5 --seed 42

  # 3) 문제 배정 (그룹 수 자동, 그대로 분배)
  julia assign.jl --students students.txt --problems probs.txt --week 3 --seed 42

  # 4) 문제 배정 (조 3개 고정, 2배 분배, 가중 배분, CSV 저장)
  julia assign.jl --students students.txt --problems probs.txt --week 3 --groups 3 --copies 2 --weighted --csv out.csv --seed 42
""")
end

function parse_args(args::Vector{String})
    opts = Dict{String,Any}(
        "print" => true,
        "weighted" => false,
    )
    i = 1
    while i <= length(args)
        a = args[i]
        if a in ["--students","-S"]; i+=1; opts["students"]=args[i]
        elseif a in ["--problems","-P"]; i+=1; opts["problems"]=args[i]
        elseif a in ["--week","-w"]; i+=1; opts["week"]=parse(Int,args[i])
        elseif a in ["--groups","-g"]; i+=1; opts["groups"]=parse(Int,args[i])
        elseif a == "--size"; i+=1; opts["size"]=parse(Int,args[i])
        elseif a in ["--copies","-c"]; i+=1; opts["copies"]=parse(Int,args[i])
        elseif a == "--seed"; i+=1; opts["seed"]=parse(Int,args[i])
        elseif a == "--weighted"; opts["weighted"]=true
        elseif a == "--no-print"; opts["print"]=false
        elseif a == "--csv"; i+=1; opts["csv"]=args[i]
        elseif a in ["--help","-h"]; opts["help"]=true
        else
            error("알 수 없는 옵션: $a (--help 참고)")
        end
        i += 1
    end
    return opts
end

# ========== 메인 ==========

if abspath(PROGRAM_FILE) == @__FILE__
    opts = parse_args(ARGS)
    if get(opts, "help", false) || !haskey(opts, "students")
        print_usage()
        exit(0)
    end

    # 입력 읽기
    students = read_list(String(opts["students"]))
    isempty(students) && error("students 파일이 비어 있습니다: $(opts["students"])")

    # 모드 판단: PROB가 없으면 '조 편성' 모드, 있으면 '배정' 모드
    if !haskey(opts, "problems")
        # ---- 조 편성 ----
        if haskey(opts, "groups")
            G = make_groups(students; n=Int(opts["groups"]),
                            seed=get(opts,"seed",nothing), print_output=Bool(opts["print"]))
        elseif haskey(opts, "size")
            G = make_groups(students; size=Int(opts["size"]),
                            seed=get(opts,"seed",nothing), print_output=Bool(opts["print"]))
        else
            error("조 편성 모드에서는 --groups 또는 --size 중 하나를 반드시 지정하세요.")
        end
        # CSV 저장 옵션(조 편성만 저장하고 싶다면 학생만 기록)
        if haskey(opts,"csv")
            path = String(opts["csv"])
            open(path,"w") do io
                println(io, "group,student")
                for (gi,g) in enumerate(G)
                    for name in g
                        println(io, string(gi, ",", csv_escape(name)))
                    end
                end
            end
            println("CSV 저장 완료: $(path)")
        end
    else
        # ---- 문제 배정 ----
        problems = read_list(String(opts["problems"]))
        isempty(problems) && error("problems 파일이 비어 있습니다: $(opts["problems"])")
        haskey(opts,"week") || error("--week W 를 지정하세요.")

        # 그룹 수 계산: --groups 우선, 없으면 --size, 둘 다 없으면 arrange가 자동 결정
        n = if haskey(opts,"groups")
            Int(opts["groups"])
        elseif haskey(opts,"size")
            ceil(Int, length(students)/Int(opts["size"]))
        else
            nothing
        end

        copies = get(opts,"copies", 1)
        seed   = get(opts,"seed", nothing)
        qmode  = get(opts,"weighted", false) ? :weighted : :balanced
        print_ = Bool(get(opts,"print", true))

        res = arrange(students, (Int(opts["week"]), problems);
                      n=n, copies=copies, seed=seed, quotas_mode=qmode, print_output=print_)

        if haskey(opts,"csv")
            save_csv(String(opts["csv"]), res, Int(opts["week"]))
        end
    end
end
