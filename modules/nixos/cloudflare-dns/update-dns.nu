
# NIX MANAGED COMMENTS
const comment_before = "nix-managed[["
const comment_after = "]]"

def "nix-comment format" [name: string]: string -> string {
    let prev_comment = $in
    let start = $comment_before + $name + $comment_after
    if ($prev_comment | is-empty) {
        $start
    } else {
        $'($start): ($prev_comment)'
    }
}
def "nix-comment extract-name" []: string -> string {
    # guaranteed by dns query params to succeed
    parse $'($comment_before){name}($comment_after){rest}' | get 0.name
}

# CLOUDFLARE CONSTANTS

# https://developers.cloudflare.com/dns/manage-dns-records/how-to/batch-record-changes/#availability-and-limits
const max_batch_operations = 200
# https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/batch/
const operation_order = {
    delete:    0
    update:    1
    create:    2
    overwrite: 3
};
# https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/batch/
const operation_parameter = {
    delete:    deletes
    update:    patches
    create:    posts
    overwrite: puts
};

def main [dns_config_file: path, --dry-run]: nothing -> nothing {
    let dns_config = open $dns_config_file

    let all_zones = cfAPI get zones

    $dns_config.domains |
    map_record {|domain, value|
        let found_zones = $all_zones | filter { $in.name == $domain }
        match ($found_zones | length) {
            0 => (user_error $"no zones found for domain '($domain)'")
            # TODO: print zone ids
            2.. => (user_error $"multiple zones found for domain '($domain)' ????")
            1 => ($value | insert zone_id ($found_zones | get 0.id))
        }
    } |
    transpose domain config |
    par-each {
        let domain = $in.domain
        let zone_id = $in.config.zone_id
        let declared_config = $in.config.dnsRecords

        let existing_record_operations = (
            cfAPI get $"zones/($zone_id)/dns_records"
            --params {
                match: all
                comment.startswith: $comment_before
                comment.contains: $comment_after
            }
        ) |
        each {|record|
            let name = $record.comment | nix-comment extract-name

            let associated_config = $declared_config | get $name -i

            {
                name: $name
                op_type: (if $associated_config == null {
                    'delete'
                } else if $associated_config.updateOnly {
                    'update'
                } else {
                    'overwrite'
                })
                prev_record: $record
                new_record: $associated_config.record?
            }
        }

        let new_record_operations = $declared_config | items {|name, config|
            if $name not-in $existing_record_operations.name {
                {
                    name: $name
                    op_type: 'create'
                    prev_record: null
                    new_record: $config.record
                }
            }
        } | compact

        let all_record_operations = $existing_record_operations ++ $new_record_operations | sort-by -c {|l, r|
            # in case there are too many operations to batch at once,
            # they are sorted in same order that cloudflare would run them
            ($operation_order | get $l.op_type) < ($operation_order | get $r.op_type)
        }

        print 'about to perform the following operations:'
        print ($all_record_operations | table --expand)

        $all_record_operations | each {|op|
            insert api_param (
                match $op.op_type {
                    delete => ($op.prev_record | select id)
                    update | create | overwrite => $op.new_record
                } |
                match $op.op_type {
                    delete | create => ()
                    update | overwrite => (insert id $op.prev_record.id)
                } |
                match $op.op_type {
                    delete => ()
                    update => (
                        # update only if present
                        # wish there was a 'update --ignore-missing'
                        if "comment" in $op.new_record {
                            update comment { nix-comment format $op.name }
                        } else {
                            $in
                        }
                    )
                    create | overwrite => (
                        default "" comment |
                        update comment { nix-comment format $op.name }
                    )
                }
            )
        } |
        chunks $max_batch_operations |
        # cannot be parallised as they must be executed in order
        each {|operations|
            let body = $operations | group-by {|op| $operation_parameter | get $op.op_type } |
                map_record {|n, v| $v | get api_param}

            print 'about to post a batch of DNS record updates:'
            print $'zone_id: ($zone_id)'
            print $'body: ($body | to json)'

            if $dry_run {
                print '--dry-run passed so not sending the request'
            } else {
                let reponse = cfAPI post $"zones/($zone_id)/dns_records/batch" $body
                print $'response: ($reponse | to json)'
            }
        }
    }
    ignore
}

def user_error [message: string]: nothing -> nothing {
    print --stderr $"error: ($message)"
    exit 1
}

def map_record [fv: closure]: record -> record {
    transpose n v |
    each {
        update v (do $fv $in.n $in.v)
    } |
    transpose -rd
}

def cfAPI [subcommand: string, endpoint: string, --params: any, data?: any] {
    let full_endpoint = {
        scheme: https
        host: api.cloudflare.com
        path: $"client/v4/($endpoint)"
        params: ($params | default {})
    } | url join
    let headers = {
        Authorization: $"Bearer ($env.CLOUDFLARE_API_TOKEN)"
        Content-Type: application/json
    }
    let body = $data | to json

    let response = match $subcommand {
        "delete" => (http delete
            $full_endpoint
            --headers $headers
            --allow-errors
        )
        "get" => (http get
            $full_endpoint
            --headers $headers
            --allow-errors
        )
        "post" => (http post
            $full_endpoint
            $body
            --headers $headers
            --allow-errors
        )
        "patch" => (http patch
            $full_endpoint
            $body
            --headers $headers
            --allow-errors
        )
        "put" => (http put
            $full_endpoint
            $body
            --headers $headers
            --allow-errors
        )
        _ => (error make {
            msg: "invalid http subcommand"
            label: {
                text: "here"
                span: (metadata $subcommand).span
            }
        })
    }

    # TODO: handle paging
    if $response.success {
        $response.result
    } else {
        user_error $"cloudflare API error\(s):\n($response.errors | to json)"
    }
}
