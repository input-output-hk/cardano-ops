#!/usr/bin/env bash
# shellcheck disable=1091,2016

run_tag() {
        jq --raw-output .meta.tag "$(realpath "${1:-.}")/meta.json"
}

cluster_last_meta_tag() {
        local meta=./last-meta.json tag dir meta2
        jq . "${meta}" >/dev/null || fail "malformed run metadata: ${meta}"

        tag=$(jq --raw-output .meta.tag "${meta}")
        test -n "${tag}" || fail "bad tag in run metadata: ${meta}"

        dir="./runs/${tag}"
        test -d "${dir}" ||
                fail "bad tag in run metadata: ${meta} -- ${dir} is not a directory"
        meta2=${dir}/meta.json
        jq --exit-status . "${meta2}" >/dev/null ||
                fail "bad tag in run metadata: ${meta} -- ${meta2} is not valid JSON"

        test "$(realpath ./last-meta.json)" = "$(realpath "${meta2}")" ||
                fail "bad tag in run metadata: ${meta} -- ${meta2} is different from ${meta}"
        echo "${tag}"
}

fetch_tag() {
        local tag
        tag=${1:-$(cluster_last_meta_tag)}

        fetch_run "./runs/${tag}"
}

analyse_tag() {
        local tag
        tag=${1:-$(cluster_last_meta_tag)}

        analyse_run "${tagroot}/${tag}" || true
}

sanity_check_tag() {
        local tag
        tag=${1:-$(cluster_last_meta_tag)}

        sanity_check_run "${tagroot}/${tag}"
}

tag_report_name() {
        local tag
        tag=${1:-$(cluster_last_meta_tag)}

        run_report_name "${tagroot}/${tag}"
}


package_tag() {
        local tag
        tag=${1:-$(cluster_last_meta_tag)}

        package_run "${tagroot}/${tag}"
}
