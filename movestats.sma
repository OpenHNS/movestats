#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define XYZ 3

new Float:g_flOrigin[MAX_PLAYERS + 1][XYZ];
new Float:g_flPrevOrigin[MAX_PLAYERS + 1][XYZ];

new g_iPrevButtons[MAX_PLAYERS + 1];
new g_iOldButtons[MAX_PLAYERS + 1];

new bool:g_isLadder[MAX_PLAYERS + 1];
new bool:g_isPrevLadder[MAX_PLAYERS + 1];

new bool:g_isGround[MAX_PLAYERS + 1];
new bool:g_isPrevGround[MAX_PLAYERS + 1];

new bool:g_inDuck[MAX_PLAYERS + 1];
new bool:g_inPrevDuck[MAX_PLAYERS + 1];

new Float:g_flHorSpeed[MAX_PLAYERS + 1];
new Float:g_flPrevHorSpeed[MAX_PLAYERS + 1];

new Float:g_flMaxSpeed[MAX_PLAYERS + 1];

new bool:g_isSGS[MAX_PLAYERS + 1];
new bool:g_isSurfing[MAX_PLAYERS + 1];
new bool:g_isArtifactLadder[MAX_PLAYERS + 1];

enum PLAYER_VER {
	IN_MIDDLE,
	IN_UPPED,
	IN_DROPPED
};

new PLAYER_VER:g_eVerInfo[MAX_PLAYERS + 1];

new Float:g_flDuckFirstZ[MAX_PLAYERS + 1];
new Float:g_flJumpFirstZ[MAX_PLAYERS + 1];

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
	ARTIFACT_DROP,
	ARTIFACT_LADDER
}

enum MOVE_STATS {
	STATS_COUNT,
	STATS_FOG[FOG_TYPE],
	Float:STATS_PRECENT,
	Float:STATS_AVG_SPEED,
	MOVE_ARTIFACTS:SATS_ARTIFACT,
}

new g_eMoveStats[MAX_PLAYERS + 1][MOVE_STATS];

new bool:g_bOneReset[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("HNS Move stats", "0.0.3", "OpenHNS");

	RegisterHookChain(RG_PM_Move, "rgPM_Move", true);

	RegisterHookChain(RG_CBasePlayer_Spawn, "rgPlayerSpawn");
}

public rgPM_Move(id) {
	if (is_user_bot(id) || is_user_hltv(id)) {
		return HC_CONTINUE;
	}

	static iFog[MAX_PLAYERS + 1];

	get_entvar(id, var_origin, g_flOrigin[id]);
	g_isLadder[id] = bool:(get_entvar(id, var_movetype) == MOVETYPE_FLY);
	g_isGround[id] = bool:(get_entvar(id, var_flags) & FL_ONGROUND);
	g_inDuck[id] = bool:(get_entvar(id, var_flags) & FL_DUCKING);
	g_iPrevButtons[id] = get_entvar(id, var_oldbuttons);
	g_flMaxSpeed[id] = get_maxspeed(id);

	new Float:flVelosity[3];
	get_entvar(id, var_velocity, flVelosity);
	g_flHorSpeed[id] = vector_hor_length(flVelosity);

	g_isGround[id] = g_isGround[id] || g_isLadder[id];

	g_isPrevGround[id] = g_isPrevGround[id] || g_isPrevLadder[id];

	if (g_isLadder[id]) {
		g_isArtifactLadder[id] = true;
	}

	if (g_isGround[id]) {
		if (iFog[id] <= 10) {
			iFog[id]++;
			g_bOneReset[id] = true;
		} else if (g_bOneReset[id]) {
			check_and_show_move(id);
			g_bOneReset[id] = false;
		}

		if (iFog[id] == 1) {
			if (g_inDuck[id]) {
				g_isSGS[id] = true;
			} else {
				g_isSGS[id] = false;
			}
		}
	} else {
		if (isUserSurfing(id, g_inDuck[id])) {
			g_isSurfing[id] = true;
		}
		
		if (g_isPrevGround[id]) {
			new bool:isDuck = !g_inDuck[id] && !(g_iPrevButtons[id] & IN_JUMP) && g_iOldButtons[id] & IN_DUCK;
			new bool:isJump = !isDuck && g_iPrevButtons[id] & IN_JUMP && !(g_iOldButtons[id] & IN_JUMP);

			if (isDuck) {
				if (iFog[id] > 10) {
					g_eVerInfo[id] = IN_MIDDLE;
					g_flDuckFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
				} else {
					if (!g_flDuckFirstZ[id]) {
						g_flDuckFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
					}
					
					if (g_eVerInfo[id] == IN_MIDDLE) {
						new Float:flDuckZ = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
						
						if (flDuckZ - g_flDuckFirstZ[id] < -4.0) {
							g_eVerInfo[id] = IN_DROPPED;
						} else if (flDuckZ - g_flDuckFirstZ[id] > 4.0) {
							g_eVerInfo[id] = IN_UPPED;
						}
					}

					move_stats_counter(id, g_isSGS[id] ? MOVE_SGS : MOVE_DDRUN, iFog[id], g_eVerInfo[id]);
				}
			}
			if (isJump) {
				if (iFog[id] > 10) {
					g_eVerInfo[id] = IN_MIDDLE;
					g_flJumpFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
				} else {
					if (!g_flJumpFirstZ[id]) {
						g_flJumpFirstZ[id] = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];
					}

					if (g_eVerInfo[id] == IN_MIDDLE) {
						new Float:flJumpZ = g_inPrevDuck[id] ? g_flPrevOrigin[id][2] + 18.0 : g_flPrevOrigin[id][2];

						if (flJumpZ - g_flJumpFirstZ[id] < -4.0) {
							g_eVerInfo[id] = IN_DROPPED;
						} else if (flJumpZ - g_flJumpFirstZ[id] > 4.0) {
							g_eVerInfo[id] = IN_UPPED;
						}
					}
					move_stats_counter(id, MOVE_BHOP, iFog[id], g_eVerInfo[id]);
				}
			}
		}

		iFog[id] = 0;
	}

	g_iOldButtons[id] = g_iPrevButtons[id];

	g_flPrevOrigin[id] = g_flOrigin[id];

	g_isPrevGround[id] = g_isGround[id];
	g_isPrevLadder[id] = g_isLadder[id];
	g_inPrevDuck[id] = g_inDuck[id];

	g_flPrevHorSpeed[id] = g_flHorSpeed[id]

	return HC_CONTINUE;
}


public move_stats_counter(id, MOVE_TYPE:eMove, iFog, PLAYER_VER:iVerInfo) {
	if (g_eSessionMoveType[id] && (g_eSessionMoveType[id] != eMove)) {
		check_and_show_move(id);
	}

	g_eSessionMoveType[id] = eMove;

	g_eMoveStats[id][STATS_COUNT]++;

	if (iVerInfo == IN_DROPPED) {
		g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_DROP; // TODO: Перебивает слайд
	}

	if (g_isArtifactLadder[id]) {
		g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_LADDER; // TODO: Сделать по красоте
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
			switch(iFog) {
				case 3: g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
				case 4: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
				default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
			}

			if (g_isSurfing[id]) {
				g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_SURF;
			}
		}
		case MOVE_DDRUN: {
			switch(iFog) {
				case 2: g_eMoveStats[id][STATS_FOG][FOG_PERFECT]++;
				case 3: g_eMoveStats[id][STATS_FOG][FOG_GOOD]++;
				default: g_eMoveStats[id][STATS_FOG][FOG_BAD]++;
			}

			if (g_isSurfing[id]) {
				g_eMoveStats[id][SATS_ARTIFACT] = ARTIFACT_SURF;
			}
		}
	}
	

	g_eMoveStats[id][STATS_AVG_SPEED] += g_flHorSpeed[id];

	g_eMoveStats[id][STATS_PRECENT] = float(g_eMoveStats[id][STATS_FOG][FOG_PERFECT]) / float(g_eMoveStats[id][STATS_COUNT]) * 100.0;
}

public clear_move_stats(id) {
	arrayset(g_flOrigin[id], 0.0, XYZ);
	arrayset(g_flPrevOrigin[id], 0.0, XYZ);

	g_iPrevButtons[id] = 0;
	g_iOldButtons[id] = 0;

	g_isLadder[id] = false;
	g_isPrevLadder[id] = false;

	g_isGround[id] = false;
	g_isPrevGround[id] = false;

	g_inDuck[id] = false;
	g_inPrevDuck[id] = false;

	g_flHorSpeed[id] = 0.0;
	g_flPrevHorSpeed[id] = 0.0;

	g_flMaxSpeed[id] = 0.0;

	g_isSGS[id] = false;
	g_isSurfing[id] = false;
	g_isArtifactLadder[id] = false;

	g_flDuckFirstZ[id] = 0.0;
	g_flJumpFirstZ[id] = 0.0;


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

public client_connect(id) {
	clear_move_stats(id);
}

public rgPlayerSpawn(id) {
	clear_move_stats(id);
}

stock Float:vector_hor_length(Float:flVel[3]) {
	new Float:flNorma = floatpower(flVel[0], 2.0) + floatpower(flVel[1], 2.0);
	if (flNorma > 0.0)
		return floatsqroot(flNorma);
		
	return 0.0;
}

stock Float:get_maxspeed(id) {
	new Float:flMaxSpeed;
	flMaxSpeed = get_entvar(id, var_maxspeed);
	
	return flMaxSpeed * 1.2;
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

/* FRONT */

enum Visual {
	not_show = 0,
	good,
	holy, 
	pro, 
	god
};

stock check_and_show_move(id) {
	if (!isSessionMove[id]) {
		clear_move_stats(id);
		return;
	}
	
	g_eMoveStats[id][STATS_AVG_SPEED] = g_eMoveStats[id][STATS_AVG_SPEED] / float(g_eMoveStats[id][STATS_COUNT]);

	new Visual:eVisual = get_visual(id);

	show_sessions(id, eVisual);

	clear_move_stats(id);
}

stock Visual:get_visual(id) {
	new Visual:eVisual = not_show;

	switch (g_eMoveStats[id][SATS_ARTIFACT]) {
		case ARTIFACT_SMESTA: {
			switch (g_eSessionMoveType[id]) {
				case MOVE_BHOP: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 290.0 && g_eMoveStats[id][STATS_PRECENT] >= 80.0) {
						eVisual = god
					} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 275.0 && g_eMoveStats[id][STATS_PRECENT] >= 70.0) {
						eVisual = holy
					} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 265.0 && g_eMoveStats[id][STATS_PRECENT] >= 60.0) {
						eVisual = pro
					} else if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
				case MOVE_SGS: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
				case MOVE_DDRUN: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
			}

		}
		case ARTIFACT_SURF, ARTIFACT_DROP: {
			switch (g_eSessionMoveType[id]) {
				case MOVE_BHOP: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
				case MOVE_SGS: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
				case MOVE_DDRUN: {
					if (g_eMoveStats[id][STATS_AVG_SPEED] >= 250.0 && g_eMoveStats[id][STATS_PRECENT] >= 50.0) {
						eVisual = good
					}
				}
			}
		}
	}

	return eVisual
}


stock show_sessions(id, Visual:eVisual) {
	// if (eVisual == not_show) {
	// 	return
	// }

	new szArtifactMess[128];
	new iLenArtifact;

	switch (g_eMoveStats[id][SATS_ARTIFACT]) {
		case ARTIFACT_SURF: {
			iLenArtifact = format(szArtifactMess[iLenArtifact], sizeof szArtifactMess - iLenArtifact, "(^3on slide^1)");
		}
		case ARTIFACT_DROP: {
			iLenArtifact = format(szArtifactMess[iLenArtifact], sizeof szArtifactMess - iLenArtifact, "(^3drop^1)");
		}
		case ARTIFACT_LADDER: {
			iLenArtifact = format(szArtifactMess[iLenArtifact], sizeof szArtifactMess - iLenArtifact, "(^3ladder^1)");
		}
	}

	new szMoveMess[128];
	new iLenMove;

	switch (g_eSessionMoveType[id]) {
		case MOVE_BHOP: {
			iLenMove = format(szMoveMess[iLenMove], sizeof szMoveMess - iLenMove, "BHOP");
		}
		case MOVE_SGS: {
			iLenMove = format(szMoveMess[iLenMove], sizeof szMoveMess - iLenMove, "SGS");
		}
		case MOVE_DDRUN: {
			iLenMove = format(szMoveMess[iLenMove], sizeof szMoveMess - iLenMove, "DDRUN");
		}
	}

	switch(eVisual) {
		case good: client_print_color(0, print_team_grey, "^3%n^1 completed ^3%d^1 %s: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1. %s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szArtifactMess);
		case holy: client_print_color(0, print_team_blue, "^3%n^1 completed ^3%d^1 %s: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1. %s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szArtifactMess);
		case pro: client_print_color(0, print_team_red, "^3%n^1 completed ^3%d^1 %s: ^3%.0f%%%^1 perfect, post avg. speed: ^3%.2f^1. %s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szArtifactMess);
		case god: client_print_color(0, print_team_red, "^3%n^4 completed ^3%d^4 %s: ^3%.0f%%%^4 perfect, post avg. speed: ^3%.2f^4. %s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szArtifactMess);
		case not_show: client_print_color(id, print_team_blue, "%n completed %d %s: %.0f%%% perfect, post avg. speed: %.2f. %s", id, g_eMoveStats[id][STATS_COUNT], szMoveMess, g_eMoveStats[id][STATS_PRECENT], g_eMoveStats[id][STATS_AVG_SPEED], szArtifactMess);
	}


}

/* FRONT */
