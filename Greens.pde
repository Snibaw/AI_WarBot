///////////////////////////////////////////////////////////////////////////
//
// The code for the Green team
// ===========================
//
///////////////////////////////////////////////////////////////////////////

class GreenTeam extends Team {
  final int MY_CUSTOM_MSG = 5;

  PVector base1, base2;

  // coordinates of the 2 bases, chosen in the rectangle with corners
  // (width/2, 0) and (width, height-100)
  GreenTeam() {
    // first base
    base1 = new PVector(width/2 - 300, (height - 100)/2 - 150);
    //base1 = new PVector(width/2 + 490, (height - 100)/2 - 190);
    // second base
    base2 = new PVector(width/2 - 300, (height - 100)/2 + 150);
    //base2 = new PVector(width/2 + 490, (height - 100)/2 + 190);
  }
}

interface GreenRobot {
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green bases
//
///////////////////////////////////////////////////////////////////////////
class GreenBase extends Base implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenBase(PVector p, color c, Team t) {
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
    brain[5].x = 4;
    brain[5].y = 1;
    brain[5].z = 2;
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
    } else if (energy > 12000) {
      // if no robot in the pipe and enough energy
      if ((int)random(2) == 0)
        // creates a new harvester with 50% chance
        brain[5].x++;
      else if ((int)random(2) == 0)
        // creates a new rocket launcher with 25% chance
        brain[5].y++;
      else
        // creates a new explorer with 25% chance
        brain[5].z++;
    }

    // creates new bullets and fafs if the stock is low and enought energy
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
      }
    }
    // clear the message queue
    flushMessages();
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the Green explorers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = exploration | 1 = go back to base)
//   4.y = (0 = no target | 1 = locked target)
//   0.x / 0.y = coordinates of the target
//   0.z = type of the target
///////////////////////////////////////////////////////////////////////////
class GreenExplorer extends Explorer implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenExplorer(PVector pos, color c, ArrayList b, Team t) {
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
    // if faf in perceived
    if (perceiveFafs() != null) {
      // "dodge" mode
      brain[4].x = 2;
      ArrayList fafsInCone = perceiveFafs();
      Missile miss = (Missile)minDist(fafsInCone);
      float an = towards(miss);
      heading = radians(180) - an;
      tryToMoveForward();
    } else {
      // if food to deposit or too few energy
      if ((carryingFood > 200) || (energy < 100))
        // time to go back to base
        brain[4].x = 1;
      else brain[4].x = 0;
    }
    
    // depending on the state of the robot
    if (brain[4].x == 1) {
      // go back to base...
      goBackToBase();
    } else {
      // if "dodge" state, dodge
      if (brain[4].x == 2) {
        tryToMoveForward();
      } else
      // ...or explore randomly
      randomMove(45);
    }

    // tries to localize ennemy bases
    lookForEnnemyBase();
    // inform harvesters about food sources
    driveHarvesters();
    // inform rocket launchers about targets
    driveRocketLaunchers();

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
      // if one is seen, look for a friend harvester
      Harvester harvey = (Harvester)oneOf(perceiveRobots(friend, HARVESTER));
      if (harvey != null)
        // if a harvester is seen, send a message to it with the position of food
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
class GreenHarvester extends Harvester implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenHarvester(PVector pos, color c, ArrayList b, Team t) {
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
    // handle messages received
    handleMessages();
    
    // if faf in perceived
    if (perceiveFafs() != null) {
      // "dodge" mode
      brain[4].x = 2;
      ArrayList fafsInCone = perceiveFafs();
      Missile miss = (Missile)minDist(fafsInCone);
      float an = towards(miss);
      heading = radians(180) - an;
      tryToMoveForward();
    } else {
      // check for the closest burger
      Burger b = (Burger)minDist(perceiveBurgers());
      if ((b != null) && (distance(b) <= 2))
        // if one is found next to the robot, collect it
        takeFood(b);
  
      // if food to deposit or too few energy
      if ((carryingFood > 200) || (energy < 100))
        // time to go back to the base
        brain[4].x = 1;
      else brain[4].x = 0;
    }

    // if in "go back" state
    if (brain[4].x == 1) {
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
    } else
      // if not in the "go back" state, explore and collect food
      // if "dodge" state, dodge
      if (brain[4].x == 2) {
        tryToMoveForward();
      } else
      goAndEat();
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
// The code for the Green rocket launchers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   0.x / 0.y = position of the target
//   0.z = breed of the target
//   4.x = (0 = look for target | 1 = go back to base | 2 = dodge Fafs)
//   4.y = (0 = no target | 1 = localized target)
///////////////////////////////////////////////////////////////////////////
class GreenRocketLauncher extends RocketLauncher implements GreenRobot {
  //
  // constructor
  // ===========
  //
  GreenRocketLauncher(PVector pos, color c, ArrayList b, Team t) {
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
    // handle received messages 
    handleMessages();
    
    // if faf in perceived
    if (perceiveFafs() != null) {
      // "dodge" mode
      brain[4].x = 2;
      ArrayList fafsInCone = perceiveFafs();
      Missile miss = (Missile)minDist(fafsInCone);
      float an = towards(miss);
      heading = radians(180) - an;
      tryToMoveForward();
    }
    // if no energy or no bullets
    else {
      if ((energy < 100) || (bullets == 0))
        // go back to the base
        brain[4].x = 1;
      else 
        // back to normal mode
        brain[4].x = 0;
    }
    if (brain[4].x == 1) {
      // if in "go back to base" mode
      goBackToBase();
    } else {
      if (brain[4].x == 2) {
        tryToMoveForward();
      } else {
        // try to find a target
        
        if (target()) {
          //target by message
          PVector directionOfTheOponent = new PVector(brain[0].x, brain[0].y);
          heading = towards(directionOfTheOponent);
        }
        
        selectTarget();
        // if target identified
        if (target()){
          // shoot on the target
          /*
          if((int) brain[0].x != (int) brain[1].x || (int) brain[0].y != (int) brain[1].y){
            //launchBullet(towards(brain[0].add(brain[0].sub(brain[1]).mult(distance(brain[0])))));
            
            
          }
          else{
            launchBullet(towards(brain[0]));
            print("Normal Launch \n");
          }
          */
          //entre 0.6 et 0.75, 0.7 semble bien
          float distanceToTarget = abs(brain[0].dist(pos));
          
          if(distanceToTarget <= 10){
            tryToMoveBackward();
          }
          
          float anticipation = 0.7;
          PVector directionOfTheOponent = new PVector(brain[0].x - brain[1].x,brain[0].y - brain[1].y,0);
          launchBullet(towards(new PVector(brain[0].x + directionOfTheOponent.x * distance(brain[0]) * anticipation
          ,brain[0].y + directionOfTheOponent.y * distance(brain[0]) * anticipation
          ,brain[0].z)));
          //print("Angle de tir = "+towards(brain[0])+"\n");
          //print("Anticipation Launch | brain[0] = ("+brain[0].x+";"+brain[0].y+") | brain[1] = ("+brain[1].x+";"+brain[1].y+") | substract = ("+(brain[0].x - brain[1].x)+";"+(brain[0].y - brain[1].y)+")\n");
        } 
        else
          // else explore randomly
          randomMove(45);       
      }
    }
  }
  
  void handleMessages() {
    float d = width;
    PVector p = new PVector();

    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized target" message
      if (msg.type == INFORM_ABOUT_TARGET) {
        // record the position of the target
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (distance(p) < d) {
          // if burger closer than closest target
          // record the position in the brain
          brain[0].x = p.x;
          brain[0].y = p.y;
          brain[0].z = msg.args[2];
          // update the distance of the closest target
          d = distance(p);
          // update the corresponding flag
          brain[4].y = 1;
        }
      }
    }
    // clear the message queue
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
      brain[1].z = bob.breed;
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
  
  void tryToMoveBackward() {
    // if there is an obstacle ahead, rotate randomly
    if (!freeAhead(speed))
      right(random(180));

    // if there is no obstacle ahead, move forward at full speed
    if (freeAhead(speed))
      forward(speed);
  }
}