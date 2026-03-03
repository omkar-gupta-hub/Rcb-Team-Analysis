Use ipl;
-- Subjective Question
-- Q1. How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?
WITH Toss_Win_Stats AS (
    SELECT v.Venue_Name,
           td.Toss_Name AS Toss_Decision,
           COUNT(*) AS Total_Matches,
           SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) AS Matches_Won_After_Toss,
           (SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) / COUNT(*)) * 100 AS Win_Percentage
    FROM matches m
    INNER JOIN toss_decision td ON m.Toss_Decide = td.Toss_Id
    INNER JOIN venue v ON m.Venue_Id = v.Venue_Id
    GROUP BY v.Venue_Name, td.Toss_Name
)
SELECT Venue_Name,
       Toss_Decision,
       Total_Matches,
       Matches_Won_After_Toss,
       Win_Percentage
FROM Toss_Win_Stats
WHERE Total_Matches >= 10
ORDER BY Win_Percentage DESC, Total_Matches DESC;

-- Q2. Suggest some of the players who would be best fit for the team.
-- For Batsman
SELECT
p.Player_Name,
ROUND(SUM(b.Runs_Scored) * 1.0 / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Runs_Per_Match
FROM
Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Player p ON b.Striker = p.Player_Id
GROUP BY
p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id) >= 5  -- filters out players who played too few matches
ORDER BY Avg_Runs_Per_Match DESC
LIMIT 10;

-- For bowler
SELECT
p.Player_Name,
COUNT(w.Player_Out) AS Total_Wickets
FROM
Ball_by_Ball b
JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id
AND b.Over_Id = w.Over_Id
AND b.Ball_Id = w.Ball_Id
AND b.Innings_No = w.Innings_No
JOIN Player p ON b.Bowler = p.Player_Id
GROUP BY
p.Player_Name
ORDER BY Total_Wickets DESC
LIMIT 10;

-- Q3. What are some of the parameters that should be focused on while selecting the players?
WITH Player_Stats AS (
  SELECT
      p.Player_Name,
      COUNT(DISTINCT m.Match_Id) AS Matches_Played,
      -- Batting metrics
      SUM(bbb.Runs_Scored) AS Total_Runs,
      AVG(bbb.Runs_Scored) AS Avg_Runs_Per_Ball,
      (SUM(bbb.Runs_Scored) /COUNT(bbb.ball_id ))* 100.0  AS Strike_Rate,
      -- Bowling metrics
      COUNT(wt.Player_Out) AS Total_Wickets
      FROM player p
  INNER JOIN ball_by_ball bbb ON p.Player_Id = bbb.Striker OR p.Player_Id = bbb.Bowler
  INNER JOIN matches m ON bbb.Match_Id = m.Match_Id
  LEFT JOIN wicket_taken wt
         ON bbb.Match_Id = wt.Match_Id
        AND bbb.Over_Id = wt.Over_Id
        AND bbb.Ball_Id = wt.Ball_Id
  GROUP BY p.Player_Name
)
SELECT
    Player_Name,
    Matches_Played,
    Total_Runs,
    ROUND(Avg_Runs_Per_Ball, 2) AS Avg_Runs_Per_Ball,
    ROUND(Strike_Rate, 2) AS Strike_Rate,
    Total_Wickets
FROM Player_Stats
WHERE Matches_Played > 10
ORDER BY
    Total_Runs DESC
LIMIT 10;

-- Question No: 4 (Which players offer versatility in their skills and can contribute effectively with both bat and ball)
-- Step 1: Calculate batting performance
CREATE TEMPORARY TABLE IF NOT EXISTS BattingPerformance AS
SELECT
    p.Player_Name,
    SUM(bbb.Runs_Scored) AS Total_Runs,
    COUNT(bbb.Ball_Id) AS Balls_Faced
FROM player p
INNER JOIN ball_by_ball bbb ON p.Player_Id = bbb.Striker
INNER JOIN matches m ON bbb.Match_Id = m.Match_Id
GROUP BY p.Player_Name;
-- Step 2: Calculate bowling performance
CREATE TEMPORARY TABLE IF NOT EXISTS BowlingPerformance AS
SELECT
    p.Player_Name,
    COUNT(bbb.Ball_Id) AS Balls_Bowled,
    SUM(bbb.Runs_Scored) AS Runs_Conceded
FROM player p
INNER JOIN ball_by_ball bbb ON p.Player_Id = bbb.Bowler
INNER JOIN matches m ON bbb.Match_Id = m.Match_Id
GROUP BY p.Player_Name;
-- Step 3: Combine both performances and calculate metrics
SELECT
    bp.Player_Name,
    bp.Total_Runs,
    (bp.Total_Runs * 100.0 / bp.Balls_Faced) AS Strike_Rate,
    wp.Runs_Conceded,
    (wp.Runs_Conceded * 1.0 / wp.Balls_Bowled) AS Economy_Rate
FROM BattingPerformance bp
INNER JOIN BowlingPerformance wp ON bp.Player_Name = wp.Player_Name
WHERE bp.Balls_Faced > 50 AND wp.Balls_Bowled > 30
ORDER BY Strike_Rate DESC, Economy_Rate ASC
LIMIT 10;

-- Q5. Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization) 
SELECT
Player_Name,
COUNT(*) AS Matches_Played,
SUM(CASE WHEN Team_Id = Match_Winner THEN 1 ELSE 0 END) AS Matches_Won,
ROUND(SUM(CASE WHEN Team_Id = Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Win_Percentage
FROM (
SELECT DISTINCT
m.Match_Id,
p.Player_Name,
pb.Team_Batting AS Team_Id,
m.Match_Winner
FROM Ball_by_Ball pb
JOIN Matches m ON pb.Match_Id = m.Match_Id
JOIN Player p ON pb.Striker = p.Player_Id
) AS player_matches
GROUP BY Player_Name
HAVING Matches_Played >= 10
ORDER BY Win_Percentage DESC
Limit 10;

-- Q6.What would you suggest to RCB before going to the mega auction?
SELECT
	p.Player_Name,
	COUNT(DISTINCT m.Match_Id) AS Matches_Played,
	SUM(CASE WHEN m.Match_Winner = b.Team_Batting THEN 1 ELSE 0 END) AS Matches_Won,
	ROUND(SUM(CASE WHEN m.Match_Winner = b.Team_Batting THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT m.Match_Id), 2) AS Win_Percentage
FROM 
	Ball_by_Ball b
	JOIN Matches m ON b.Match_Id = m.Match_Id
	JOIN Player p ON b.Striker = p.Player_Id
WHERE 
	b.Team_Batting = 2
GROUP BY 
	p.Player_Name
HAVING 
	Matches_Played >= 10
ORDER BY 
	Win_Percentage DESC
LIMIT 10;

-- Q7. What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies 
SELECT
v.Venue_Name,
ROUND(SUM(b.Runs_Scored) * 1.0 / COUNT(b.Ball_Id), 2) AS Avg_Runs_Per_Ball
FROM Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Venue v ON m.Venue_Id = v.Venue_Id                  
GROUP BY v.Venue_Name
ORDER BY Avg_Runs_Per_Ball DESC;


-- Q8. Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.
SELECT
    t.Team_Name AS Team,
    v.Venue_Name AS Home_Venue,
    COUNT(DISTINCT m.Match_Id) AS Matches_Played_At_Home,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins_At_Home,
    ROUND(SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT m.Match_Id), 2) AS Win_Percentage_At_Home
FROM Matches m
JOIN Venue v ON m.Venue_Id = v.Venue_Id
JOIN Team t ON m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id
WHERE v.Venue_Name LIKE '%Chinnaswamy%'
AND t.team_name ='Royal Challengers Bangalore'
GROUP BY t.Team_Name, v.Venue_Name
ORDER BY Win_Percentage_At_Home DESC;

-- Q9.Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy. 
WITH RCB_Performance AS (
    SELECT
        m.Season_Id,
        COUNT(m.Match_Id) AS Matches_Played,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
        SUM(CASE WHEN m.Match_Winner != t.Team_Id THEN 1 ELSE 0 END) AS Matches_Lost,
        (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) / COUNT(m.Match_Id)) * 100 AS Win_Percentage
    FROM matches m
    INNER JOIN team t ON t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2
    WHERE t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Season_Id
)
SELECT
    s.Season_Year,
    rp.Matches_Played,
    rp.Matches_Won,
    rp.Matches_Lost,
    rp.Win_Percentage
FROM RCB_Performance rp
INNER JOIN season s ON rp.Season_Id = s.Season_Id
ORDER BY s.Season_Year;
