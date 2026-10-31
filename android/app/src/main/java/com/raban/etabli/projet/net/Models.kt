// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.net

import org.json.JSONObject

// HAL+JSON parsing helpers.
// Require identity/display fields; additional HAL fields remain forward compatible.

private fun JSONObject.linkTitle(name: String): String? =
    optJSONObject("_links")?.optJSONObject(name)?.optString("title")?.ifBlank { null }

data class OPMe(val id: Int, val name: String, val email: String?) {
    companion object {
        fun parse(o: JSONObject) = OPMe(
            id = o.getInt("id").also { require(it > 0) { "Invalid object ID" } },
            name = o.getString("name"),
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
            id = o.getInt("id").also { require(it > 0) { "Invalid object ID" } },
            identifier = o.optString("identifier").ifBlank { null },
            name = o.getString("name"),
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
            id = o.getInt("id").also { require(it > 0) { "Invalid object ID" } },
            subject = o.getString("subject"),
            statusTitle = o.linkTitle("status"),
            typeTitle = o.linkTitle("type"),
            priorityTitle = o.linkTitle("priority"),
            projectTitle = o.linkTitle("project"),
            assigneeTitle = o.linkTitle("assignee"),
        )
    }
}
