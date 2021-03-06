require "test_helper"

class CommitTest < ActiveSupport::TestCase
  attr_reader :project



  context "When parsing the commit message, it" do
    should "extract an array of tags from the front of a commit" do
      commits = [
        "[skip] don't look at me",
        "[new-feature] i'm fancy",
        "[fix] [refactor] [c_i] i don't like talking about my flare",
        "[tight-fit]right up by the text"
      ]

      expectations = [
        %w{skip},
        %w{new-feature},
        %w{fix refactor c_i},
        %w{tight-fit}
      ]

      commits.zip(expectations) do |commit_message, expectation|
        assert_equal expectation, Commit.new(message: commit_message).tags
      end
    end


    should "extract an array of ticket numbers from the end of a commit" do
      commits = [
        "I did some work [#1347]",
        "Two birds, one stone [#45] [#88]"
      ]

      expectations = [
        [1347],
        [45, 88]
      ]

      commits.zip(expectations) do |commit_message, expectation|
        assert_equal expectation, Commit.new(message: commit_message).ticket_numbers
      end
    end


    should "extract extra attributes from a commit" do
      commits = [
        "I did some work {{attr:value}}",
        "I set this one twice {{attr:v1}} {{attr:v2}}"
      ]

      expectations = [
        {"attr" => ["value"]},
        {"attr" => ["v1", "v2"]}
      ]

      commits.zip(expectations) do |commit_message, expectation|
        assert_equal expectation, Commit.new(message: commit_message).extra_attributes
      end
    end


    should "ignore spaces when extracting extra attributes from a commit" do
      commits = [
        "I did some work {{attr: value}}",
        "I set this one twice {{attr:\tv1}} {{attr: v2}}",
        "I set this one three times {{attr:v1, v2,v3}}",
      ]

      expectations = [
        {"attr" => ["value"]},
        {"attr" => ["v1", "v2"]},
        {"attr" => ["v1", "v2", "v3"]}
      ]

      commits.zip(expectations) do |commit_message, expectation|
        assert_equal expectation, Commit.new(message: commit_message).extra_attributes
      end
    end


    should "extract time from a commit" do
      commits = [
        "I did some work (45m)",
        "I did some work (6 min)",
        "I did some work (.2hrs)",
        "I did some work (1hr)"
      ]

      expectations = [
        0.75,
        0.1,
        0.2,
        1
      ]

      commits.zip(expectations) do |commit_message, expectation|
        assert_equal expectation, Commit.new(message: commit_message).hours_worked
      end
    end


    should "extract a clean message from a commit" do
      commits = [
        "[tag] I did some work {{attr:value}} [#45] (18m)"
      ]

      expectations = [
        "I did some work"
      ]

      commits.zip(expectations) do |commit_message, expectation|
        assert_equal expectation, Commit.new(message: commit_message).clean_message
      end
    end
  end



  should "skip merge commits" do
    merge_commits = [
      "Merge branch example",
      "Merge remote-tracking branch example",
      "Merge pull request"
    ]

    merge_commits.each do |commit_message|
      assert_equal true, Commit.new(message: commit_message).skip?, "Was supposed to recognize #{commit_message.inspect} as a merge commit"
    end
  end



  context "The clean commit message" do
    should "not include recognized tickets, tags, and time" do
      commit_message = "[tag] I did some work {{attr:value}} [#45] (18m)"

      assert_equal "I did some work", Commit.new(message: commit_message).clean_message,
        "Expected the clean message not to contain the extra information"
    end

    should "omit manual line breaks" do
      # Many committers follow a convention where a commit message is manually
      # broken to fit within 80-character lines. When this convention is used,
      # we will remove the manual line breaks and let the commit message be
      # wrapped in whatever context it is used.
      commit_message = "Long line that might\nexceed 80 characters"

      assert_equal "Long line that might exceed 80 characters", Commit.new(message: commit_message).clean_message,
        "Expected the clean message to replace single line breaks with spaces"
    end

    should "omit descriptions" do
      # Git Tower follows a convention where a commit can have a shorter summary
      # and a longer detailed description. It puts two line breaks between the summary
      # and the description when composing the commit message. When this convention
      # is used, we are interested in just the summary
      commit_message = "Short summary\n\nDetailed Description"

      assert_equal "Short summary", Commit.new(message: commit_message).clean_message,
        "Expected the clean message not to contain the commit description"
    end
  end



  context "#identify_committers" do
    setup do
      user = User.first
      user.alias_emails = %w{bob@gmail.com}
      user.save!
    end

    should "find users by their primary email address" do
      commit = Commit.new(committer_email: "admin@example.com")
      assert_equal 1, commit.identify_committers.count
    end

    should "find users by their secondary email address" do
      commit = Commit.new(committer_email: "bob@gmail.com")
      assert_equal 1, commit.identify_committers.count
    end

    should "find users only once when several email addresses match" do
      stub(Houston::Commits.config).identify_committers(anything).returns %w{admin@example.com bob@gmail.com}
      mock.proxy(User).with_email_address(%w{admin@example.com bob@gmail.com}).once

      commit = Commit.new
      assert_equal 1, commit.identify_committers.count, "Should find the user given two of his email addresses"
    end
  end



private

  def params(overrides)
    overrides.reverse_merge({
      project: project,
      sha: SecureRandom.hex(16),
      message: "nothing to see here",
      authored_at: Time.now,
      committer: "Houston",
      committer_email: "commitbot@houston.com"
    })
  end

end
