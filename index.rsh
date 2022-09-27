'reach 0.1';

export const main = Reach.App(() => {

  const VoteCordinator = Participant('VoteCordinator', {
    votingPeriod:UInt,
    getVoteDuration: Fun([],UInt),
    votingReady: Fun([],Null),
    finalVote: Fun([UInt,UInt],Null),
  });
  const Voter = API('Voter', {
    vote: Fun([UInt],Tuple(UInt)),
  });

  // now initialize the contract
  init();

  // create a helper function for determing votes cast
  const determineAdditionOfVotes = (vote,contestantIndex) => {
    // contestant index 1 for Candidate 1 and 2 for Candidate 2
    return vote == contestantIndex ? 1:0
  }

  // 1. The Vote Coordinator publishes the voting period
  // first get the voting period from (VoteCordinator local step)
  VoteCordinator.only(() => {
    const ctcVotingPeriod = declassify(interact.votingPeriod)
  })
  VoteCordinator.publish(ctcVotingPeriod);
  commit();

  
  //2. While the voting period hasn't elapsed(use timeout and parallel reduce)

  // publish something in order to enter into a concesus step for the loop
  VoteCordinator.only(() => {
  });

  VoteCordinator.publish();
  const end = lastConsensusTime() + ctcVotingPeriod;

  const [ firstCandidateVotes, secondCandidateVotes ] = parallelReduce([ 0, 0 ])
    .invariant(balance() >= 0 )
    .while(lastConsensusTime() <= end )

    //3. Voters publishes their votes to the smart contract through voter API
    .api_(Voter.vote, (vote) => {

      return [vote, (notify) => {
        notify([vote]);
        
        return [
          firstCandidateVotes +  determineAdditionOfVotes(vote,1),
          secondCandidateVotes + determineAdditionOfVotes(vote,2),
        ]
        
      }];
    })
    // .timeout(absoluteTime(end), () => {
    .timeout(absoluteTime(end), () => {
      VoteCordinator.publish();
      return [firstCandidateVotes, secondCandidateVotes]
    });

  // transfer any remaining funds in the contact to the vote VoteCordinator' account
  transfer(balance()).to(VoteCordinator);
  // commit to go back to the context step here
  commit();

  // 4. When the voting period elapses the contract determines the winner based on the number of cast votes
  VoteCordinator.interact.finalVote(firstCandidateVotes,secondCandidateVotes)

  // terminate the contract
  exit();
});




