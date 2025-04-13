#include <amxmodx>
#include <fakemeta>
#include <reapi>

enum MOVE_TYPE {
	MOVE_NOT = 0,
	MOVE_BHOP,
	MOVE_SGS,
	MOVE_DDRUN
}

new MOVE_TYPE:g_eSessionMoveType[MAX_PLAYERS + 1];
new bool:isSessionMove[MAX_PLAYERS + 1];

enum FOG_TYPE {
	FOG_PERFECT,
	FOG_GOOD,
	FOG_BAD
};

enum MOVE_ARTIFACTS {
	ARTIFACT_SMESTA,
	ARTIFACT_SURF,
	ARTIFACT_DROP
}

enum MOVE_STATS {
	STATS_COUNT,
	STATS_FOG[FOG_TYPE],
	Float:STATS_PRECENT,
	Float:STATS_AVG_SPEED,
	MOVE_ARTIFACTS:SATS_ARTIFACT,
}

new g_eMoveStats[MAX_PLAYERS + 1][MOVE_STATS];

new g_iFog[MAX_PLAYERS + 1];

new g_iOldButtons[MAX_PLAYERS + 1];

new Float:g_flPrevOrigin[MAX_PLAYERS + 1][3];
new bool:g_isOldGround[MAX_PLAYERS + 1];
new bool:g_bPrevLadder[MAX_PLAYERS + 1];
new bool:g_bPrevInDuck[MAX_PLAYERS + 1];

new bool:g_isSGS[MAX_PLAYERS + 1];

new Float:g_flHorSpeed[MAX_PLAYERS + 1];
new Float:g_flPrevHorSpeed[MAX_PLAYERS + 1];

new bool:g_bOneReset[MAX_PLAYERS + 1];

new g_iDucks[MAX_PLAYERS + 1];
new g_iJumps[MAX_PLAYERS + 1];

enum PLAYER_VER {
	IS_MIDDLE,
	IS_UPPED,
	IS_DROPPED
};

new PLAYER_VER:g_iVerInfo[MAX_PLAYERS + 1];
new Float:g_flDuckFirstZ[MAX_PLAYERS + 1];
new Float:g_flJumpFirstZ[MAX_PLAYERS + 1];

new Float:g_flMaxSpeed[MAX_PLAYERS + 1];

new bool:g_bMoveOldSurfing[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("HNS Move stats", "0.0.1", "OpenHNS");

	RegisterHookChain(RG_PM_Move, "rgPM_Move", true);
}

public rgPM_Move(id) {
	if (is_user_bot(id) || is_user_hltv(id)) {
		return HC_CONTINUE;
	}

	new Float:flOrigin[3];
	get_entvar(id, var_origin, flOrigin);

	new bool:isLadder = bool:(get_entvar(id, var_movetype) == MOVETYPE_FLY);
	new bool:isGround = bool:(get_entvar(id, var_flags) & FL_ONGROUND);

	new bool:inDuck = bool:(get_entvar(id, var_flags) & FL_DUCKING);

	new iPrevButtons = get_entvar(id, var_oldbuttons);
	
	new Float:flVelosity[3]
	get_entvar(id, var_velocity, flVelosity);
	g_flHorSpeed[id] = vector_hor_length(flVelosity);

	isGround = isGround || isLadder;

	g_isOldGround[id] = g_isOldGround[id] || g_bPrevLadder[id];

	if (isGround) {
		g_iFog[id]++;

		if (g_iFog[id] == 1) {
			if (inDuck) {
				g_isSGS[id] = true;
			} else {
				g_isSGS[id] = false;
			}
		}

		if (g_iFog[id] <= 10) {
			g_bOneReset[id] = true;
		} else if (g_bOneReset[id]) {
			check_and_show_move(id);
			g_bOneReset[id] = false;
		}

	} else {
		if (isUserSurfing(id, inDuck)) {
			g_bMoveOldSurfing[id] = true;
		}
		if (g_isOldGround[id]) {
			new bool:isDuck = !inDuck && !(iPrevButtons & IN_JUMP) && g_iOldButtons[id] & IN_DUCK;
			new bool:isJump = !isDuck && iPrevButtons & IN_JUMP && !(g_iOldButtons[id] & IN_JUMP);

			if (isDuck) {
				if (g_iFog[id] > 10) {
					g_iDucks[id] = 0;
					g_iVerInfo[id] = IS_MIDDLE;
					g_flDuckFirstZ[id] = g_bPrevInDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
				} else {
					g_iDucks[id]++;
					if (!g_flDuckFirstZ[id]) {
						g_flDuckFirstZ[id] = g_bPrevInDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
					}
					
					if (g_iVerInfo[id] == IS_MIDDLE) {
						new Float:flDuckZ = g_bPrevInDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
						
						if (flDuckZ - g_flDuckFirstZ[id] < -4.0) {
							g_iVerInfo[id] = IS_DROPPED;
						} else if (flDuckZ - g_flDuckFirstZ[id] > 4.0) {
							g_iVerInfo[id] = IS_UPPED;
						}
					}

					move_stats_counter(id, g_isSGS[id] ? MOVE_SGS : MOVE_DDRUN, g_iFog[id], g_iVerInfo[id]);
				}
			}
			if (isJump) {
				if (g_iFog[id] > 10) {
					g_iJumps[id] = 0;
					g_iVerInfo[id] = IS_MIDDLE;
					g_flJumpFirstZ[id] = g_bPrevInDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
				} else {
					g_iJumps[id]++;

					if (!g_flJumpFirstZ[id]) {
						g_flJumpFirstZ[id] = g_bPrevInDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
					}

					if (g_iVerInfo[id] == IS_MIDDLE) {
						new Float:flJumpZ = g_bPrevInDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];

						if (flJumpZ - g_flJumpFirstZ[id] < -4.0) {
							g_iVerInfo[id] = IS_DROPPED;
						} else if (flJumpZ - g_flJumpFirstZ[id] > 4.0) {
							g_iVerInfo[id] = IS_UPPED;
						}
					}
				}
				move_stats_counter(id, MOVE_BHOP, g_iFog[id], g_iVerInfo[id]);
			}
		}

		g_iFog[id] = 0;
	}

	g_iOldButtons[id] = iPrevButtons;

	g_flPrevOrigin[id] = flOrigin;

	g_isOldGround[id] = isGround;
	g_bPrevLadder[id] = isLadder;
	g_bPrevInDuck[id] = inDuck;

	g_flPrevHorSpeed[id] = g_flHorSpeed[id]

	return HC_CONTINUE;
}


public move_stats_counter(id, MOVE_TYPE:eMove, iFog, PLAYER_VER:iVerInfo) {
	if (g_eSessionMoveType[id] && (g_eSessionMoveType[id] != eMove)) {
		check_and_show_move(id);
	}

	g_eSessionMoveType[id] = eMove;

	g_eMoveStats[id][STATS_COUNT]++;

	if (iVerInfo == IS_DROPPED) {
		g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_DROP;
	}

	if (g_eMoveStats[id][STATS_COUNT] >= 5) {
		isSessionMove[id] = true;
	}

	switch(eMove) {
		case MOVE_BHOP: {
			if (g_flHorSpeed[id] < g_flMaxSpeed[id] && (iFog == 1 || iFog >= 2 && g_flPrevHorSpeed[id] > g_flMaxSpeed[id])) {
				g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
			} else {
				switch(iFog) {
					case 1..2: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
					default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
				}
			}
		}
		case MOVE_SGS: {
			switch(g_iFog[id]) {
				case 3: g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
				case 4: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
				default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
			}

			if (g_bMoveOldSurfing[id]) {
				g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_SURF;
			}
		}
		case MOVE_DDRUN: {
			switch(g_iFog[id]) {
				case 2: g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
				case 3: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
				default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
			}

			if (g_bMoveOldSurfing[id]) {
				g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_SURF;
			}
		}
	}
	

	g_eMoveStats[id][STATS_AVG_SPEED] += g_flHorSpeed[id];

	g_eMoveStats[id][STATS_PRECENT] = float(g_eMoveStats[id][STATS_FOG][FOG_PERFECT]) / float(g_eMoveStats[id][STATS_COUNT]) * 100.0;
}

stock check_and_show_move(id) {
	if (!isSessionMove[id]) {
		clear_move_stats(id);
		return;
	}
	
	g_eMoveStats[id][STATS_AVG_SPEED] = g_eMoveStats[id][STATS_AVG_SPEED] / float(g_eMoveStats[id][STATS_COUNT]);

	new szMoveInfoMess[128];
	new iLen;

	switch (g_eMoveStats[id][SATS_ARTIFACT]) {
		case ARTIFACT_SURF: {
			iLen += format(szMoveInfoMess[iLen], sizeof szMoveInfoMess - iLen, " (^3on slide^1)");
		}
		case ARTIFACT_DROP: {
			iLen += format(szMoveInfoMess[iLen], sizeof szMoveInfoMess - iLen, " (^3drop^1)");
		}
	}

	switch(g_eSessionMoveType[id]) {
		case MOVE_BHOP: {
			//if (g_eMoveStats[id][STATS_COUNT] > 5 && g_eMoveStats[id][STATS_AVG_SPEED] > 250.0 && g_eMoveStats[id][STATS_PRECENT] > 50.0) {
				client_print_color(0, print_team_blue, "^3%n^1 completed ^3%d^1 BHOP: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1.%s", id, g_eMoveStats[id][STATS_COUNT], g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szMoveInfoMess);
			//}
		}
		case MOVE_SGS: {
			//if (g_eMoveStats[id][STATS_COUNT] > 5 && g_eMoveStats[id][STATS_AVG_SPEED] > 250.0 && g_eMoveStats[id][STATS_PRECENT] > 50.0) {
				client_print_color(0, print_team_blue, "^3%n^1 completed ^3%d^1 SGS: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1.%s", id, g_eMoveStats[id][STATS_COUNT], g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szMoveInfoMess);
			//}
		}
		case MOVE_DDRUN: {
			//if (g_eMoveStats[id][STATS_COUNT] > 5 && g_eMoveStats[id][STATS_AVG_SPEED] > 250.0 && g_eMoveStats[id][STATS_PRECENT] > 30.0) {
				client_print_color(0, print_team_blue, "^3%n^1 completed ^3%d^1 DDRUN: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1.%s", id, g_eMoveStats[id][STATS_COUNT], g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szMoveInfoMess);
			//}
		}
	}

	clear_move_stats(id);
}

public clear_move_stats(id) {
	isSessionMove[id] = false;
	g_eSessionMoveType[id] = MOVE_NOT;
	g_eMoveStats[id][STATS_COUNT] = 0;

	g_eMoveStats[id][STATS_FOG][FOG_PERFECT] = 0;
	g_eMoveStats[id][STATS_FOG][FOG_GOOD] = 0;
	g_eMoveStats[id][STATS_FOG][FOG_BAD] = 0;

	g_eMoveStats[id][STATS_PRECENT] = 0.0;

	g_eMoveStats[id][STATS_AVG_SPEED] = 0.0;

	g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_SMESTA;
}

stock Float:vector_hor_length(Float:flVel[3]) {
	new Float:flNorma = floatpower(flVel[0], 2.0) + floatpower(flVel[1], 2.0);
	if (flNorma > 0.0)
		return floatsqroot(flNorma);
		
	return 0.0;
}

stock bool:isUserSurfing(id, bool:inDuck) {
	new Float:origin[3], Float:dest[3];
	get_entvar(id, var_origin, origin);
	
	dest[0] = origin[0];
	dest[1] = origin[1];
	dest[2] = origin[2] - 1.0;

	new Float:flFraction;

	engfunc(EngFunc_TraceHull, origin, dest, 0, 
		inDuck ? HULL_HEAD : HULL_HUMAN, id, 0);

	get_tr2(0, TR_flFraction, flFraction);

	if (flFraction >= 1.0) return false;
	
	get_tr2(0, TR_vecPlaneNormal, dest);

	return dest[2] <= 0.7;
}