///////////////////////////////////////////////////////////////////////////
//
// The code for the red team
// ===========================
//
///////////////////////////////////////////////////////////////////////////

class RedTeam extends Team {
  final int MY_CUSTOM_MSG = 5;
  
  PVector base1, base2;

  // coordinates of the 2 bases, chosen in the rectangle with corners
  // (width/2, 0) and (width, height-100)
  RedTeam() {
    // first base
    base1 = new PVector(width/2 + 300, (height - 100)/2 - 150);
    // second base
    base2 = new PVector(width/2 + 300, (height - 100)/2 + 150);
  }  
}

interface RedRobot {
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green bases
//
///////////////////////////////////////////////////////////////////////////
class RedBase extends Base implements RedRobot {
  //
  // constructor
  // ===========
  //
  RedBase(PVector p, color c, Team t) {
    super(p, c, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the base
  //
  void setup() {
    // creates a new harvester
    newHarvester();
    // 7 more harvesters to create
    brain[5].x = 5;
    brain[5].y = 3;
    brain[5].z = 3;
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    // handle received messages 
    handleMessages();

    // creates new robots depending on energy and the state of brain[5]
    if ((brain[5].x > 0) && (energy >= 1000 + harvesterCost)) {
      // 1st priority = creates harvesters 
      if (newHarvester())
        brain[5].x--;
    } else if ((brain[5].y > 0) && (energy >= 1000 + launcherCost)) {
      // 2nd priority = creates rocket launchers 
      if (newRocketLauncher())
        brain[5].y--;
    } else if ((brain[5].z > 0) && (energy >= 1000 + explorerCost)) {
      // 3rd priority = creates explorers 
      if (newExplorer())
        brain[5].z--;
    } else if (energy > 8000) {
      // if no robot in the pipe and enough energy 
      if ((int)random(2) == 0)
        // creates a new harvester with 50% chance
        brain[5].x++;
      // else if ((int)random(2) == 0)
      //   // creates a new rocket launcher with 25% chance
      //   brain[5].y++;
      // else
      //   // creates a new explorer with 25% chance
      //   brain[5].z++;
      //Create a new rocket launcher with 50 % chance
      else 
        brain[5].y++;
    }

    // creates new bullets and faf if the stock is low and enought energy
    if ((bullets < 10) && (energy > 1000))
      newBullets(50);
    if ((fafs < 10) && (energy > 1000))
      newFafs(10);

    // if ennemy rocket launcher in the area of perception
    Robot bob = (Robot)minDist(perceiveRobots(ennemy, LAUNCHER));
    if (bob != null) {
      heading = towards(bob);
      // launch a faf if no friend robot on the trajectory...
      if (perceiveRobotsInCone(friend, heading) == null)
        launchFaf(bob);
      if(perceiveRobotsInCone(friend, heading) != null || baseNbFafs == 0)
      {
        //Alert the rocket launchers
        ArrayList<Robot> rocky = perceiveRobots(friend, LAUNCHER);
        for (int i = 0; i < rocky.size(); i++) {
          informAboutTarget(rocky.get(i), bob);
        }
      }
    }
  }

  //
  // handleMessage
  // =============
  // > handle messages received since last activation 
  //
  void handleMessages() {
    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      msg = messages.get(i);
      if (msg.type == ASK_FOR_ENERGY) {
        // if the message is a request for energy
        if (energy > 1000 + msg.args[0]) {
          // gives the requested amount of energy only if at least 1000 units of energy left after
          giveEnergy(msg.alice, msg.args[0]);
        }
      } else if (msg.type == ASK_FOR_BULLETS) {
        // if the message is a request for energy
        if (energy > 1000 + msg.args[0] * bulletCost) {
          // gives the requested amount of bullets only if at least 1000 units of energy left after
          giveBullets(msg.alice, msg.args[0]);
        }
      } else if(msg.type == INFORM_ABOUT_TARGET) {
        informNearRobotsAboutTarget((int)msg.args[3]);
      }

    }
    // clear the message queue
    flushMessages();
  }
  // TD3 : I.2. Send information about the target to the robots in the area of perception
  void informNearRobotsAboutTarget(int idTarget) {
      ArrayList<Robot> rocky = perceiveRobots(friend, LAUNCHER); 
      for (int i = 0; i < rocky.size(); i++) {
        informAboutTarget(rocky.get(i), game.getRobot(idTarget));
      }

  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green explorers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = exploration | 1 = go back to base)
//   4.y = (0 = no target | 1 = locked target)
//   0.x / 0.y = coordinates of the target
//   0.z = type of the target
///////////////////////////////////////////////////////////////////////////
class RedExplorer extends Explorer implements RedRobot {
  //
  // constructor
  // ===========
  //
  RedExplorer(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
    brain[1].x = pos.x;
    brain[1].y = pos.y;
    brain[1].z = 0;
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {

    handleMessages();
    Faf faf = (Faf)minDist(perceiveFafs());
    if (faf != null) {
      RunAwayFromFafs(faf);
    }
    // if food to deposit or too few energy
    if ((carryingFood > 200) || (energy < 100))
      // time to go back to base
      brain[4].x = 1;

    // Base basey = (Base)minDist(myBases);
    // depending on the state of the robot
    if (brain[4].x == 1) {
      // go back to base...
      goBackToBase();
    } 
    else {
      // ...or explore randomly
      randomMove(45);
    }

    // tries to localize ennemy bases
    lookForEnnemyBase();
    // inform harvesters about food sources
    driveHarvesters();
    // inform rocket launchers about targets
    driveRocketLaunchers();

    UnstuckExploreur();
    
  }
  void UnstuckExploreur()
  {
    //Check if the robot is moving
    if(brain[1].x == pos.x && brain[1].y == pos.y)
    {
      //If not, increment the counter
      brain[1].z++;
    }
    else
    {
      //If yes, reset the counter
      brain[1].z = 0;
    }
    //If the robot is stuck, find the closest wall and go in the opposite direction
    if(brain[1].z > 10)
    {
      Wall wally = (Wall)minDist(perceiveWalls());
      if (wally != null) {
        heading = towards(wally) + radians(180);
        tryToMoveForward();
      }
    }
    brain[1].x = pos.x;
    brain[1].y = pos.y;
  }
    void handleMessages() {
    float d = width;
    PVector p = new PVector();

    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized food" message
      if (msg.type == HARVESTER_FULL) {
        brain[0].x = msg.args[0];
        brain[0].y = msg.args[1];
        heading = towards(brain[0]);
        tryToMoveForward();
      }
    }
    // clear the message queue
    flushMessages();
  }

  //
  // setTarget
  // =========
  // > locks a target
  //
  // inputs
  // ------
  // > p = the location of the target
  // > breed = the breed of the target
  //
  void setTarget(PVector p, int breed) {
    brain[0].x = p.x;
    brain[0].y = p.y;
    brain[0].z = breed;
    brain[4].y = 1;
  }
  void RunAwayFromFafs(Faf faf)
  {
    //Go in the opposite direction of the faf
    heading = towards(faf) + radians(180);
    tryToMoveForward();
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest base, either to deposit food or to reload energy
  //
  void goBackToBase() {
    // bob is the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one (not all of my bases have been destroyed)
      float dist = distance(bob);

      if (dist <= 2) {
        // if I am next to the base
        if (energy < 500)
          // if my energy is low, I ask for some more
          askForEnergy(bob, 1500 - energy);
        if (carryingFood > 200)
          // if I carry food, I give it to the base
          giveFood(bob, carryingFood);
        // switch to the exploration state
        brain[4].x = 0;
        // make a half turn
        right(180);
      } else {
        // if still away from the base
        // head towards the base (with some variations)...
        heading = towards(bob) + random(-radians(20), radians(20));
        // ...and try to move forward 
        tryToMoveForward();
      }
    }
  }

  //
  // target
  // ======
  // > checks if a target has been locked
  //
  // output
  // ------
  // true if target locket / false if not
  //
  boolean target() {
    return (brain[4].y == 1);
  }

  //
  // driveHarvesters
  // ===============
  // > tell harvesters if food is localized
  //
  void driveHarvesters() {
    // look for burgers
    Burger zorg = (Burger)oneOf(perceiveBurgers());
    if (zorg != null) {
      Harvester harvey = (Harvester)oneOf(perceiveRobots(friend, HARVESTER));
      if (harvey != null)
        informAboutFood(harvey, zorg.pos);
    }
  }

  //
  // driveRocketLaunchers
  // ====================
  // > tell rocket launchers about potential targets
  //
  void driveRocketLaunchers() {
    // look for an ennemy robot 
    Robot bob = (Robot)oneOf(perceiveRobots(ennemy));
    if (bob != null) {
      // if one is seen, look for a friend rocket launcher
      RocketLauncher rocky = (RocketLauncher)oneOf(perceiveRobots(friend, LAUNCHER));
      if (rocky != null)
        // if a rocket launcher is seen, send a message with the localized ennemy robot
        informAboutTarget(rocky, bob);
    }
  }

  //
  // lookForEnnemyBase
  // =================
  // > try to localize ennemy bases...
  // > ...and to communicate about this to other friend explorers
  //
  void lookForEnnemyBase() {
    // look for an ennemy base
    Base babe = (Base)oneOf(perceiveRobots(ennemy, BASE));
    if (babe != null) {
      // if one is seen, look for a friend explorer
      Explorer explo = (Explorer)oneOf(perceiveRobots(friend, EXPLORER));
      if (explo != null)
        // if one is seen, send a message with the localized ennemy base
        informAboutTarget(explo, babe);
      // look for a friend base
      Base basy = (Base)oneOf(perceiveRobots(friend, BASE));
      if (basy != null)
        // if one is seen, send a message with the localized ennemy base
        informAboutTarget(basy, babe);
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    // if there is an obstacle ahead, rotate randomly
    if (!freeAhead(speed))
      right(random(360));

    // if there is no obstacle ahead, move forward at full speed
    if (freeAhead(speed))
      forward(speed);
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green harvesters
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = look for food | 1 = go back to base) 
//   4.y = (0 = no food found | 1 = food found)
//   0.x / 0.y = position of the localized food
///////////////////////////////////////////////////////////////////////////
class RedHarvester extends Harvester implements RedRobot {
  //
  // constructor
  // ===========
  //
  RedHarvester(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
    brain[1].x = 0; // Was localized food ?
    brain[1].y = 0; 
    brain[1].z = 0; // Was picking food ?
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    // handle messages received
    handleMessages();

    ArrayList<Burger> burgers = perceiveBurgers();
    if(burgers != null)
    {
      for(int i = 0; i < burgers.size(); i++)
      {
        if(distance(burgers.get(i)) <= 2)
        {
          takeFood(burgers.get(i));
          // Save the position of the food
          brain[1].x = burgers.get(i).pos.x;
          brain[1].y = burgers.get(i).pos.y;
          brain[1].z = 1;
        }
      }
    }
    else 
    {
      //No burgers seen, the robot can come back to the base if needed
      brain[1].z = 0;
    }

    Faf faf = (Faf)minDist(perceiveFafs());
    if (faf != null) {
      RunAwayFromFafs(faf);
    }

    // if food to deposit or too few energy
    if ((carryingFood > 200) || (energy < 100))
      // time to go back to the base
      brain[4].x = 1;
    else brain[4].x = 0;
    
    
    //If the harvester has a lot of food and is far to the base, give food to an explorer
    if(carryingFood > 100 && distance(minDist(myBases)) > basePerception && energy > 100) {
      Explorer explo = (Explorer)oneOf(perceiveRobots(friend, EXPLORER));
      if (explo != null)
        giveFood(explo, carryingFood);
      else
      {
        Explorer explo2 = (Explorer)minDist(perceiveRobots(friend, EXPLORER));
        if (explo2 != null)
        {
          sendMessage(explo2, HARVESTER_FULL, new float[] {pos.x, pos.y});
        }
          
      }
    }

    // if in "go back" state and no food found recently
    if (brain[4].x == 1 && brain[1].z == 0) {
      // go back to the base
      goBackToBase();

      // if enough energy and food
      if ((energy > 100) && (carryingFood > 100)) {
        // check for closest base
        Base bob = (Base)minDist(myBases);
        if (bob != null) {
          // if there is one and the harvester is in the sphere of perception of the base
          if (distance(bob) < basePerception)
            // plant one burger as a seed to produce new ones
            plantSeed();
        }
      }
    } else if(brain[1].z == 1) // If found was found last frame
    {
      //Head towards last seen food
      heading = towards(new PVector(brain[1].x, brain[1].y));
      tryToMoveForward();
    }else
      // if not in the "go back" state, explore and collect food
      goAndEat();
    
    // ManageWall();
  }
  // void ManageWall()
  // {
  //   Robot bob = (Robot)minDist(perceiveRobots(ennemy));
  //   if(energy > 300 && bob == null) // not getting attacked
  //   {
  //     Wall wally = (Wall)minDist(perceiveWalls());
  //     if (wally != null) {
  //       print("takeWall");
  //       takeWall(wally);
  //     }
  //   }
  //   else //If the harvester is being attacked, drop walls to distract the ennemy
  //   {
  //     if(brain[1].z <= 0)
  //     {
  //       dropWall();
  //       brain[1].z = 10;
  //     }
  //     else
  //     {
  //       brain[1].z--;
  //     }
  //   }
  // }
  void RunAwayFromFafs(Faf faf)
  {
    //Go in the opposite direction of the faf
    heading = towards(faf) + radians(180);
    tryToMoveForward();
  }
  //
  // goBackToBase
  // ============
  // > go back to the closest friend base
  //
  void goBackToBase() {
    // look for the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one
      float dist = distance(bob);
      if ((dist > basePerception) && (dist < basePerception + 1))
        // if at the limit of perception of the base, drops a wall (if it carries some)
        dropWall();

      if (dist <= 2) {
        // if next to the base, gives the food to the base
        giveFood(bob, carryingFood);
        if (energy < 500)
          // ask for energy if it lacks some
          askForEnergy(bob, 1500 - energy);
        // go back to "explore and collect" mode
        brain[4].x = 0;
        // make a half turn
        right(180);
      } else {
        // if still away from the base
        // head towards the base (with some variations)...
        heading = towards(bob) + random(-radians(20), radians(20));
        // ...and try to move forward
        tryToMoveForward();
      }
    }
  }

  //
  // goAndEat
  // ========
  // > go explore and collect food
  //
  void goAndEat() {
    // look for the closest wall
    Wall wally = (Wall)minDist(perceiveWalls());
    // look for the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      float dist = distance(bob);
      // if wall seen and not at the limit of perception of the base 
      if ((wally != null) && ((dist < basePerception - 1) || (dist > basePerception + 2)))
        // tries to collect the wall
        takeWall(wally);
    }

    // look for the closest burger
    Burger zorg = (Burger)minDist(perceiveBurgers());
    if (zorg != null) {
      // if there is one
      if (distance(zorg) <= 2)
        // if next to it, collect it
        takeFood(zorg);
      else {
        // if away from the burger, head towards it...
        heading = towards(zorg) + random(-radians(20), radians(20));
        // ...and try to move forward
        tryToMoveForward();
      }
    } else if (brain[4].y == 1) {
      // if no burger seen but food localized (thank's to a message received)
      if (distance(brain[0]) > 2) {
        // head towards localized food...
        heading = towards(brain[0]);
        // ...and try to move forward
        tryToMoveForward();
      } else
        // if the food is reached, clear the corresponding flag
        brain[4].y = 0;
    } else {
      // if no food seen and no food localized, explore randomly
      heading += random(-radians(45), radians(45));
      tryToMoveForward();
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    // if there is an obstacle ahead, rotate randomly
    if (!freeAhead(speed))
      right(random(360));

    // if there is no obstacle ahead, move forward at full speed
    if (freeAhead(speed))
      forward(speed);
  }

  //
  // handleMessages
  // ==============
  // > handle messages received
  // > identify the closest localized burger
  //
  void handleMessages() {
    float d = width;
    PVector p = new PVector();

    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized food" message
      if (msg.type == INFORM_ABOUT_FOOD) {
        // record the position of the burger
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (distance(p) < d) {
          // if burger closer than closest burger
          // record the position in the brain
          brain[0].x = p.x;
          brain[0].y = p.y;
          // update the distance of the closest burger
          d = distance(p);
          // update the corresponding flag
          brain[4].y = 1;
        }
      }
    }
    // clear the message queue
    flushMessages();
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green rocket launchers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   0.x / 0.y = position of the target
//   0.z = breed of the target
//   4.x = (0 = look for target | 1 = go back to base) 
//   4.y = (0 = no target | 1 = localized target)
///////////////////////////////////////////////////////////////////////////
class RedRocketLauncher extends RocketLauncher implements RedRobot {

  //
  // constructor
  // ===========
  //
  RedRocketLauncher(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    
    handleMessages();
    // if no energy or no bullets
    if ((energy < 100) || (bullets == 0))
      // go back to the base
      brain[4].x = 1;
    else brain[4].x = 0;

    Faf faf = (Faf)minDist(perceiveFafs());
        if (faf != null) {
          RunAwayFromFafs(faf);
        }

    if (brain[4].x == 1) {
      // if in "go back to base" mode
      goBackToBase();
    } else {
      // try to find a target
      selectTarget();
      // if target identified
      if (target())
      {
          // shoot on the target
          moveTowardsTarget();
          launchBulletWithPrediction();
      }
      else
        // else explore randomly
        randomMove(45);
    }
  }
    void launchBulletWithPrediction()
    {
      if(brain[1].x != 0 && brain[1].y != 0 && brain[1].z != 0) // If we have a previous position of the target
      {
        PVector direction = PVector.sub(brain[0], brain[1]); //Calculate the direction to the target
        //Add the direction to the target position
        PVector predictedPosition = PVector.add(brain[0], direction);
        launchBullet(towards(predictedPosition));
      }
      else
      {
        launchBullet(towards(new PVector(brain[0].x, brain[0].y)));
      }
    }
  void RunAwayFromFafs(Faf faf)
  {
    //Go in the opposite direction of the faf
    heading = towards(faf) + radians(180);
    tryToMoveForward();
  }
    void moveTowardsTarget() {
      heading = towards(brain[0]);
  
      tryToMoveForward();
    }
    void handleMessages() {
      Message msg;
      // for all messages
      for (int i = 0; i < messages.size(); i++) {
        msg = messages.get(i);

        if (msg.type == INFORM_ABOUT_TARGET) {
          brain[0].x = msg.args[0];
          brain[0].y = msg.args[1];
          brain[0].z = msg.args[2];
          brain[4].y = 1; 
        }
      }
      flushMessages();
    }

  //
  // selectTarget
  // ============
  // > try to localize a target
  //
  void selectTarget() {
    // look for the closest ennemy robot
    Robot bob = (Robot)minDist(perceiveRobots(ennemy));
    if (bob != null) {

      brain[1].x = brain[0].x;
      brain[1].y = brain[0].y;
      brain[1].z = brain[0].z;
      // if one found, record the position and breed of the target
      brain[0].x = bob.pos.x;
      brain[0].y = bob.pos.y;
      brain[0].z = bob.breed;
      // locks the target
      brain[4].y = 1;
    } else
      // no target found
      brain[4].y = 0;
  }

  //
  // target
  // ======
  // > checks if a target has been locked
  //
  // output
  // ------
  // > true if target locket / false if not
  //
  boolean target() {
    return (brain[4].y == 1);
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest base
  //
  void goBackToBase() {
    // look for closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one, compute its distance
      float dist = distance(bob);

      if (dist <= 2) {
        // if next to the base
        if (energy < 500)
          // if energy low, ask for some energy
          askForEnergy(bob, 1500 - energy);
        // go back to "exploration" mode
        brain[4].x = 0;
        // make a half turn
        right(180);
      } else {
        // if not next to the base, head towards it... 
        heading = towards(bob) + random(-radians(20), radians(20));
        // ...and try to move forward
        tryToMoveForward();
      }
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    // if there is an obstacle ahead, rotate randomly
    if (!freeAhead(speed))
      right(random(360));

    // if there is no obstacle ahead, move forward at full speed
    if (freeAhead(speed))
      forward(speed);
  }
}
