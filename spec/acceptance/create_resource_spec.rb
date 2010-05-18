require 'spec_helper'

feature "Creating new resources" do
  
  scenario "Creating a resource in a collection" do
    
    projects = Almodovar::Resource("http://movida.example.com/projects", auth)
    
    stub_auth_request(:post, "http://movida.example.com/projects").with do |req|
      # we parse because comparing strings is too fragile because of order changing, different indentations, etc.
      # we're expecting something very close to this:
      # <project>
      #   <name>Wadus</name>
      # </project>      
      Nokogiri.parse(req.body).at_xpath("/project/name").text == "Wadus"
    end.to_return(:body => %q{
      <project>
        <name>Wadus</name>
        <link rel="self" href="http://movida.example.com/projects/1"/>
      </project>
    })
    
    project = projects.create(:name => "Wadus")
    
    project.should be_a(Almodovar::Resource)
    project.name.should == "Wadus"
    
    stub_auth_request(:get, "http://movida.example.com/projects/1").to_return(:body => %q{
      <project>
        <name>Wadus</name>
        <link rel="self" href="http://movida.example.com/projects/1"/>
      </project>
    })
    
    project.name == Almodovar::Resource(project.url, auth).name
  end
  
  scenario "Creating a resource expanding links" do
    stub_auth_request(:post, "http://movida.example.com/projects").with do |req|
      # <project>
      #   <name>Wadus</name>
      #   <template>Basic</template>
      # </project>
      xml = Nokogiri.parse(req.body)
      xml.at_xpath("/project/name").text == "Wadus" &&
      xml.at_xpath("/project/template").text == "Basic"
    end.to_return(:body => %q{
      <project>
        <name>Wadus</name>
        <template>Basic</template>
        <link rel="self" href="http://movida.example.com/projects/1"/>
        <link rel="tasks" href="http://movida.example.com/projects/1/tasks">
          <tasks type="array">
            <task>
              <name>Starting Meeting</name>
            </task>
          </tasks>
        </link>
      </project>
    })
    
    projects = Almodovar::Resource("http://movida.example.com/projects", auth, :expand => :tasks)    
    project = projects.create(:name => "Wadus", :template => "Basic")
    
    project.should be_a(Almodovar::Resource)
    project.name.should == "Wadus"
    project.tasks.size.should == 1
    project.tasks.first.name.should == "Starting Meeting"
  end
  
  scenario "Creating nested resources" do
    projects = Almodovar::Resource("http://movida.example.com/projects", auth)
    
    stub_auth_request(:post, "http://movida.example.com/projects").with do |req|
      # <project>
      #   <name>Wadus</name>
      #   <link rel="tasks">
      #     <tasks type="array">
      #       <task>
      #         <name>Start project</name>
      #       </task>
      #     </tasks>
      #   </link>
      # </project>
      xml = Nokogiri.parse(req.body)
      xml.at_xpath("/project/name").text == "Wadus" &&
      xml.at_xpath("/project/link[@rel='tasks']/tasks[@type='array']/task/name").text == "Start project"
    end.to_return(:body => %q{
      <project>
        <name>Wadus</name>
        <link rel="self" href="http://movida.example.com/projects/1"/>
        <link rel="tasks" href="http://movida.example.com/projects/1/tasks"/>
      </project>
    })
    
    project = projects.create(:name => "Wadus", :tasks => [{:name => "Start project"}])
    
    project.should be_a(Almodovar::Resource)
    project.name.should == "Wadus"
    
    stub_auth_request(:get, "http://movida.example.com/projects/1/tasks").to_return(:body => %q{
      <tasks type="array">
        <task>
          <name>Start project</name>
        </task>
      </tasks>
    })
    
    project.tasks.first.name.should == "Start project"    
  end
  
end