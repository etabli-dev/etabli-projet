// Copyright 2026 Raban Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.net

import org.json.JSONObject

// HAL+JSON parsing helpers.
// Only the fields we surface in the UI are decoded — keeps spec drift quiet.

private fun JSONObject.linkTitle(name: String): String? =
    optJSONObject("_links")?.optJSONObject(name)?.optString("title")?.ifBlank { null }

data class OPMe(val id: Int, val name: String, val email: String?) {
    companion object {
        fun parse(o: JSONObject) = OPMe(
            id = o.optInt("id"),
            name = o.optString("name"),
            email = o.optString("email").ifBlank { null },
        )
    }
}

data class OPProject(
    val id: Int,
    val identifier: String?,
    val name: String,
    val description: String?,
) {
    companion object {
        fun parse(o: JSONObject) = OPProject(
            id = o.optInt("id"),
            identifier = o.optString("identifier").ifBlank { null },
            name = o.optString("name"),
            description = o.optJSONObject("description")?.optString("raw")?.ifBlank { null },
        )
    }
}

data class OPWorkPackage(
    val id: Int,
    val subject: String,
    val statusTitle: String?,
    val typeTitle: String?,
    val priorityTitle: String?,
    val projectTitle: String?,
    val assigneeTitle: String?,
) {
    companion object {
        fun parse(o: JSONObject) = OPWorkPackage(
            id = o.optInt("id"),
            subject = o.optString("subject"),
            statusTitle = o.linkTitle("status"),
            typeTitle = o.linkTitle("type"),
            priorityTitle = o.linkTitle("priority"),
            projectTitle = o.linkTitle("project"),
            assigneeTitle = o.linkTitle("assignee"),
        )
    }
}
