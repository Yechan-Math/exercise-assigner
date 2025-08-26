# Student Grouping & Problem Assignment Automation (Julia)

Automate **student group formation** and **problem assignment** with fair and reproducible results.
This project was developed with assistance from an LLM; human-authored final structure, editing, integration, and review by Yechan Lee.

* Use it to **only create groups**, or
* **Assign problems** to groups and students.
* Works in terminal (CLI), Jupyter/REPL, and supports **CSV exports**.

> **Guarantee:** No problem is duplicated within the same group or for the same student.
> (To keep this guarantee, set `copies ≤ number of groups`.)

---

## 1. Requirements

* **Julia 1.9+** (recommended)
* Script file: `assign.jl`
* Input files (UTF-8 plain text)

  * `students.txt` : one student name per line
  * `problems.txt` : one problem name per line

Example:

```
# students.txt
Alice
Bob
Charlie
...

# problems.txt
Q1
Q2
Q3
...
```

---

## 2. Quick Start (CLI)

### 2.1 Groups only

By number of groups:

```bash
julia assign.jl --students students.txt --groups 4 --seed 42
```

By maximum group size:

```bash
julia assign.jl --students students.txt --size 5 --seed 42
```

Export CSV:

```bash
julia assign.jl --students students.txt --groups 4 --csv groups.csv
```

### 2.2 Problem assignment

Default (no duplication; groups auto):

```bash
julia assign.jl --students students.txt --problems problems.txt --week 3 --seed 42
```

Fixed 3 groups, 2× copies, weighted by group size, save CSV:

```bash
julia assign.jl --students students.txt --problems problems.txt --week 3 \
  --groups 3 --copies 2 --weighted --csv assignment_w3.csv --seed 42
```

CSV only (no console print):

```bash
julia assign.jl --students students.txt --problems problems.txt --week 3 \
  --groups 3 --csv out.csv --no-print
```

> macOS: `chmod +x assign.jl` then `./assign.jl ...`
> Windows: run `julia assign.jl ...`

---

## 3. CLI Options

**Input**

* `--students PATH` *(required)*
* `--problems PATH` *(required in assignment mode)*
* `--week W` *(required in assignment mode)*

**Group specification** (choose one; required in *group-only* mode, optional in assignment mode)

* `--groups N` : number of groups
* `--size M` : max members per group (N calculated automatically)

**Assignment**

* `--copies C` : replication factor (default 1). **Must satisfy `C ≤ groups`** to avoid duplicates.
* `--weighted` : distribute total problem count proportional to group sizes (else uniform)

**Output/Other**

* `--csv PATH` : save results to CSV

  * Group-only: `group,student`
  * Assignment: `week,group,student,problems`
* `--seed SEED` : shuffle seed for reproducibility
* `--no-print` : suppress console output
* `--help` : print usage

---

## 4. CSV Formats

Assignment mode:

```csv
week,group,student,problems
3,1,"Alice","Q1 | Q5"
3,1,"Bob","Q3"
3,2,"Charlie","Q2 | Q4"
...
```

Group-only mode:

```csv
group,student
1,"Alice"
1,"Bob"
2,"Charlie"
...
```

---

## 5. Jupyter/REPL Example

```julia
include("assign.jl")

students = ["Alice","Bob","Charlie","Dana","Evan","Fay","Gail","Hank","Ivy","Jack"]
problems = ["P$(i)" for i in 1:7]
week = 3

# 1) Groups only
G = make_groups(students; n=3, seed=42)

# 2) Assignment (no replication)
res = arrange(students, (week, problems); n=3, copies=1, seed=42)

# 3) Assignment (2×, weighted)
res2 = arrange(students, (week, problems); n=3, copies=2, quotas_mode=:weighted, seed=42, print_output=false)

# 4) Minimal CSV export
open("assignment.csv","w") do io
    println(io, "week,group,student,problems")
    for r in res
        println(io, string(week, ",", r.group, ",", "\"", r.student, "\"", ",", "\"", join(r.problems, " | "), "\""))
    end
end
```

---

## 6. How It Works (Brief)

1. **Group formation:** shuffle students, split as evenly as possible.
2. **Problems → groups:** compute per-group quotas (uniform or weighted). Assign each problem's copies across **different groups only** using multi-pass + swap to avoid collisions.
3. **Within-group → students:** round-robin distribution of unique problems to students (no duplicates per student).

Constraint: to avoid duplicates, ensure `copies ≤ groups`.

---

## 7. FAQ / Troubleshooting

* `copies ≤ groups` error → increase groups or reduce copies.
* Empty input files → check paths/encoding (UTF-8) and blank lines.
* Reproducibility → set `--seed`.
* Encoding in Jupyter → standard `open("w")` is UTF-8 by default; no extra package needed.
* Empty groups → ensure `groups ≤ number of students`.

---

## 8. Public API (for reuse)

```julia
make_groups(
    students::Vector{String};
    n::Union{Nothing,Int}=nothing,
    size::Union{Nothing,Int}=nothing,
    seed::Union{Nothing,Int}=nothing,
    print_output::Bool=true
) -> Vector{Vector{String}}
```

```julia
arrange(
    students::Vector{String},
    P::Tuple{<:Any, Vector{String}};   # (week, problems)
    n::Union{Nothing,Int}=nothing,     # default: max(2, floor(sqrt(k)))
    copies::Int=1,
    seed::Union{Nothing,Int}=nothing,
    quotas_mode::Symbol=:balanced,     # :balanced | :weighted
    print_output::Bool=true
) -> Vector{NamedTuple{(:group,:student,:problems),Tuple{Int,String,Vector{String}}}}
```

---

## 9. Example Console Output

```
Week 3 Assignment (×2)

Group 1 (size: 4) - problems: 5
  Alice - Q1 / Q5
  Bob   - Q3
  Charlie - Q2
  Dana    - Q4

Group 2 (size: 3) - problems: 5
  Evan - Q7
  Fay  - Q6
  Gail - Q1 / Q3
...
```

---

## 10. Tips

* Open CSVs directly with Excel.
* Record `--seed` for reproducible releases.
* Keep small sample inputs + expected outputs for PR checks / CI.

---

## 11. Contributing

* Open issues for bugs/ideas.
* In PRs, include sample inputs/expected outputs and update README if behavior changes.

---

## 12. License

MIT — see the `LICENSE` file in the repository.

---

<details>
<summary><strong>한국어 메뉴얼</strong></summary>

# 학생 조 편성 & 문제 배정 자동화 (Julia)

수업 준비 시간을 줄이고, 공정하고 재현 가능한 방식으로 **학생 조 편성**과 **문제 배정**을 자동화하는 줄리아 스크립트입니다.

* **조만 편성**하거나
* **문제를 조/학생에게 배정**할 수 있습니다.
* 터미널(커맨드라인), 주피터노트북, REPL 모두에서 사용 가능하며 **CSV 저장**을 지원합니다.

> **주요 기능:** 같은 문제가 **같은 조/같은 학생에게 중복되지 않도록** 배정합니다.
> (단, 복제 배수 `copies`는 **그룹 수 `n` 이하**여야 중복 없는 배정이 가능합니다.)

---

## 1. 요구 사항

* **Julia 1.9+** (권장)
* 스크립트 파일: `assign.jl`
* 입력 파일(UTF-8 텍스트)

  * `students.txt` : 학생 이름을 한 줄에 하나
  * `problems.txt` : 문제 이름을 한 줄에 하나

예시(텍스트 파일):

```
# students.txt
김가
김나
김다
...

# problems.txt
Q1
Q2
Q3
...
```

---

## 2. 빠른 시작(커맨드라인)

### 2.1 조만 편성

**조 개수로 지정**

```bash
julia assign.jl --students students.txt --groups 4 --seed 42
```

**조당 최대 인원으로 지정**

```bash
julia assign.jl --students students.txt --size 5 --seed 42
```

**CSV로 저장**

```bash
julia assign.jl --students students.txt --groups 4 --csv groups.csv
```

### 2.2 문제 배정

**그대로 분배(복제 X, 기본값) + 그룹 수 자동**

```bash
julia assign.jl --students students.txt --problems problems.txt --week 3 --seed 42
```

**조 3개 고정, 2배 배정, 인원 비례, CSV 저장**

```bash
julia assign.jl --students students.txt --problems problems.txt --week 3 \
  --groups 3 --copies 2 --weighted --csv assignment_w3.csv --seed 42
```

**콘솔 출력 없이 CSV만 저장**

```bash
julia assign.jl --students students.txt --problems problems.txt --week 3 \
  --groups 3 --csv out.csv --no-print
```

> macOS: `chmod +x assign.jl` 후 `./assign.jl ...` 실행 가능
> Windows: `julia assign.jl ...` 실행

---

## 3. 커맨드라인 옵션

### 입력

* `--students PATH` *(필수)* : 학생 파일 경로
* `--problems PATH` *(배정 모드에서 필수)* : 문제 파일 경로
* `--week W` *(배정 모드에서 필수)* : 주차(정수, CSV에도 기록)

### 그룹 지정(둘 중 하나, **조 편성 모드**에서는 필수 / **배정 모드**에서는 생략 시 자동)

* `--groups N` : 조 개수 직접 지정
* `--size M` : 조당 최대 인원으로부터 필요한 조 개수 자동 계산

### 배정 옵션

* `--copies C` : 문제 복제 배수(기본 1, 예: 2, 3 …)
  **중요:** 중복 없는 배정을 위해 `copies ≤ groups` 필요
* `--weighted` : 각 조 인원수에 **비례**해 총 문제 수 배분(없으면 균등)

### 출력/기타

* `--csv PATH` : 결과를 CSV로 저장

  * 조 편성 모드: `group,student`
  * 배정 모드: `week,group,student,problems`
* `--seed SEED` : 셔플 시드(정수). 재현 가능한 결과에 유용
* `--no-print` : 콘솔 출력 생략
* `--help` : 도움말 출력

---

## 4. CSV 출력 형식

### 배정 모드(`--csv assignment.csv`)

```csv
week,group,student,problems
3,1,"김가","Q1 | Q5"
3,1,"김나","Q3"
3,2,"김다","Q2 | Q4"
...
```

### 조 편성 모드(`--csv groups.csv`)

```csv
group,student
1,"김가"
1,"김나"
2,"김다"
...
```

> 쉼표/따옴표를 포함한 이름도 안전하게 저장되도록 이스케이프 처리합니다.

---

## 5. 주피터노트북/REPL 사용 예

```julia
include("assign.jl")

students = ["김가","김나","김다","김라","김마","김바","김사","김아","김자","김차"]
problems = ["P$(i)" for i in 1:7]
week = 3

# 1) 조만 편성
G = make_groups(students; n=3, seed=42)

# 2) 문제 배정 (그대로 분배)
res = arrange(students, (week, problems); n=3, copies=1, seed=42)

# 3) 2배 배정 + 인원 비례
res2 = arrange(students, (week, problems); n=3, copies=2, quotas_mode=:weighted, seed=42, print_output=false)

# 4) 간단 CSV 저장(주피터 내부)
open("assignment.csv","w") do io
    println(io, "week,group,student,problems")
    for r in res
        println(io, string(week, ",", r.group, ",", "\"", r.student, "\"", ",", "\"", join(r.problems, " | "), "\""))
    end
end
```

---

## 6. 동작 원리(요약)

1. **조 편성**: 학생을 셔플한 뒤 몫/나머지로 가능한 균등하게 나눕니다.
2. **문항 → 조**: 각 조의 쿼터(총 문제 수)를 계산하고, 각 문제의 복제본을 서로 다른 조에만 배정(두 패스+스왑)하여 **조 내부 중복 없음**을 보장합니다.
3. **조 내부 → 학생**: 조가 받은 *서로 다른 문제*를 라운드로빈으로 학생에게 분배하여 **학생 중복 없음**을 보장합니다.

> 제약: 중복 없는 배정을 위해 `copies ≤ groups` 필요.

---

## 7. 자주 묻는 질문 / 오류 해결

* **`copies ≤ groups` 오류**
  → 조 수를 늘리거나 `copies`를 줄이세요.
* **`students.txt` / `problems.txt`가 비어 있음**
  → UTF-8 인코딩, 빈 줄 제거, 경로 확인.
* **재현 가능한 결과가 필요**
  → `--seed 42`처럼 시드 고정.
* **주피터 인코딩 문제**
  → 파일 저장은 표준 `open("w")`, 별도 패키지 불필요.
* **빈 그룹 발생**
  → `--groups`가 학생 수보다 크지 않게(`n ≤ 학생 수`).

---

## 8. 내장 함수 API

```julia
make_groups(
    students::Vector{String};
    n::Union{Nothing,Int}=nothing,
    size::Union{Nothing,Int}=nothing,
    seed::Union{Nothing,Int}=nothing,
    print_output::Bool=true
) -> Vector{Vector{String}}
```

* `n` 또는 `size` 중 **하나만** 지정. 반환은 조별 학생 리스트.

```julia
arrange(
    students::Vector{String},
    P::Tuple{<:Any, Vector{String}};   # (week, problems)
    n::Union{Nothing,Int}=nothing,     # 생략 시 자동: max(2, floor(sqrt(k)))
    copies::Int=1,                     # 복제 배수(1,2,3,…), 중복 없는 배정엔 copies ≤ n
    seed::Union{Nothing,Int}=nothing,
    quotas_mode::Symbol=:balanced,     # :balanced | :weighted
    print_output::Bool=true
) -> Vector{NamedTuple{(:group,:student,:problems),Tuple{Int,String,Vector{String}}}}
```

---

## 9. 예시 콘솔 출력

```
3차 연습문제 배정 (복제배수: ×2)

1조 (인원: 4) - 배정 문제 수: 5
  김가 - Q1 / Q5
  김나 - Q3
  김다 - Q2
  김라 - Q4

2조 (인원: 3) - 배정 문제 수: 5
  김마 - Q7
  김바 - Q6
  김사 - Q1 / Q3
...
```

---

## 10. 업무 자동화 팁

* **CSV → 엑셀**: 쉼표 구분으로 바로 열 수 있습니다.
* **버전 고정**: 결과 재현이 중요하면 `--seed`를 기록해 두세요.
* **샘플/테스트**: `students_sample.txt`, `problems_sample.txt`와 기대 출력(텍스트)을 함께 두고, PR 시 자동 확인하도록 GitHub Actions(선택) 구성 추천.
* **확장 아이디어**: 난이도 태그 균형, 조 이름 접두어(A조/B조), 주차별 히스토리 로그 등.

---

## 11. 기여 방법

1. 개선 제안/버그 제보는 GitHub **Issues**에 남겨주세요.
2. PR 시: 간단한 예시 입력과 기대 출력 포함, README 반영.

---

## 12. 라이선스

MIT — 자세한 내용은 저장소의 'LICENSE' 파일을 참조하세요.
</details>
