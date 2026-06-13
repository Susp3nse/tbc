/**
 * Discover zones and encounters for an expansion.
 * WCL expansion IDs: 1=Classic, 2=TBC, 3=WotLK
 */
export function discoverZonesQuery(expansionId) {
  return `
    query {
      worldData {
        expansion(id: ${expansionId}) {
          name
          zones {
            id
            name
            encounters {
              id
              name
            }
          }
        }
      }
    }
  `;
}

/**
 * Fetch top character rankings for an encounter.
 * className: "Druid", "Warrior", etc.
 * specName: "Feral", "Arms", etc.
 * metric: "dps" or "hps"
 */
export function rankingsQuery(encounterID, className, specName, metric = 'dps', page = 1) {
  return `
    query {
      worldData {
        encounter(id: ${encounterID}) {
          name
          characterRankings(
            className: "${className}"
            specName: "${specName}"
            metric: ${metric}
            page: ${page}
          )
        }
      }
    }
  `;
}

/**
 * Fetch report metadata including fights list.
 */
export function reportFightsQuery(reportCode) {
  return `
    query {
      reportData {
        report(code: "${reportCode}") {
          code
          title
          startTime
          endTime
          fights {
            id
            name
            encounterID
            startTime
            endTime
            kill
            difficulty
            fightPercentage
            bossPercentage
            friendlyPlayers
          }
          masterData {
            actors(type: "Player") {
              id
              name
              type
              subType
              server
            }
          }
        }
      }
    }
  `;
}
